// The Flight render state for whichever context Lime handed us, behind one interface.
//
// ts/ writes this per backend: a sample's render.ts re-exports exactly one of render.dom.ts,
// render.canvas.ts or render.webgl.ts, and each of those registers only the kinds that sample draws.
// Lime picks the backend for us instead — `window.context.type` — so the switch lives here and a
// sample's Main.hx just says which kinds it needs:
//
//   renderer = new Renderer(window, 0xffffffff);
//   renderer.useShapes();
//   renderer.useTextLabels();
//
// The opt-in is the point, not ceremony: registering only what a sample draws is what lets DCE drop
// the rest, the same reason ts/ hard-codes one backend per sample rather than shipping a switch.
//
// Selecting a backend at build time:
//
//   lime build html5            WEBGL   (default; hardware="false" in project.xml gives CANVAS)
//   lime build html5 -Dcanvas   CANVAS
//   lime build html5 -Ddom      DOM
//   lime build neko             OPENGL, or CAIRO with hardware="false"
package;

import LimeCanvas.CairoCanvas;
import LimeCanvas.GlCanvas;
import flighthq.sdk.Sdk.*;
import lime.graphics.RenderContextType;
import lime.ui.Window;

enum Backend {
  DOM;
  CANVAS;
  CAIRO;
  GL;
}

@:keep
class Renderer {
  public var backend(default, null):Backend;
  public var state(default, null):Dynamic;

  /** ts/ reads `window.devicePixelRatio || 1`; Lime calls the same thing `window.scale`. */
  public var scale(default, null):Float;

  // Texture resolvers for the canvas rasterizer the GL and DOM backends fall back on for vector
  // fills. Built once and shared, so a sample using both shapes and sprites transcodes each source
  // once rather than per lane.
  var rasterResolvers:Dynamic = null;
  var glMaterialReady = false;

  public function new(window:Window, backgroundColor:Null<Int>, imageSmoothingEnabled:Null<Bool> = null) {
    scale = window.scale;

    final options:Dynamic = {
      pixelRatio: scale,
      sceneGraphSyncPolicy: 'requiresInvalidation',
      backgroundColor: backgroundColor,
    };
    if (imageSmoothingEnabled != null) options.imageSmoothingEnabled = imageSmoothingEnabled;

    switch (window.context.type) {
      case RenderContextType.DOM:
        backend = DOM;
        // Lime's DOM context is the <div> it renders into; Flight's DOM backend positions its
        // elements inside exactly such a host, so it needs to be a positioned box of known size.
        final host:Dynamic = window.context.dom;
        host.style.position = 'relative';
        host.style.width = window.width + 'px';
        host.style.height = window.height + 'px';
        host.style.overflow = 'hidden';
        state = createDomRenderState(host, options);

      case RenderContextType.CANVAS:
        backend = CANVAS;
        // The 2D context's own canvas element is what createCanvasRenderState expects: it calls
        // getContext('2d') on it and reads width/height off it.
        final context2D:Dynamic = window.context.canvas2D;
        state = createCanvasRenderState(context2D.canvas, options);

      case RenderContextType.CAIRO:
        backend = CAIRO;
        // Kept as its own branch even though it currently drives the same Flight canvas entry points,
        // because cairo-specific entry points are being commissioned upstream. When they land, only
        // this case and the draw switch below change.
        state = createCanvasRenderState(new CairoCanvas(window), options);

      case RenderContextType.OPENGL | RenderContextType.OPENGLES | RenderContextType.WEBGL:
        backend = GL;
        state = createGlRenderState(new GlCanvas(window), options);

      default:
        throw 'Unsupported Lime render context: ' + window.context.type;
    }
  }

  // ---- per-kind opt-in -----------------------------------------------------

  public function useShapes():Void {
    switch (backend) {
      case DOM:
        registerRenderer(state, ShapeKind, defaultDomShapeRenderer);
        registerCanvasShapeCommands(state, defaultCanvasShapeCommands);
        // The DOM shape renderer draws no paths itself: it allocates a <canvas> per Shape and hands
        // the commands to a registered rasterizer. Without one, every shape silently draws nothing.
        registerDomShapeRasterizer(state, createCanvasShapeRasterizer(resolvers()));
      case CANVAS | CAIRO:
        registerRenderer(state, ShapeKind, defaultCanvasShapeRenderer);
        registerCanvasShapeCommands(state, defaultCanvasShapeCommands);
      case GL:
        registerRenderer(state, ShapeKind, defaultGlShapeRenderer);
        registerGlShapeCommands(state, defaultGlShapeCommands);
        // Gradient and texture fills have no tessellated form on the GPU lane, so they draw through
        // an explicit canvas rasterizer alongside it.
        registerGlShapeRasterizer(state, createCanvasShapeRasterizer(resolvers()));
        glMaterial();
    }
  }

  public function useSprites():Void {
    switch (backend) {
      case DOM:
        registerRenderer(state, SpriteKind, defaultDomSpriteRenderer);
        registerDomImageTextureResolver(state);
        registerDomBitmapTextureResolver(state);
      case CANVAS | CAIRO:
        registerRenderer(state, SpriteKind, defaultCanvasSpriteRenderer);
        registerCanvasImageTextureResolver(getCanvasRenderStateTextureResolvers(state));
        registerCanvasBitmapTextureResolver(getCanvasRenderStateTextureResolvers(state));
      case GL:
        registerRenderer(state, SpriteKind, defaultGlSpriteRenderer);
        registerStandardGlTextureResolvers(state);
        glMaterial();
    }
  }

  public function useTextLabels():Void {
    switch (backend) {
      case DOM:
        registerRenderer(state, TextLabelKind, defaultDomTextLabelRenderer);
      case CANVAS | CAIRO:
        registerRenderer(state, TextLabelKind, defaultCanvasTextLabelRenderer);
      case GL:
        registerRenderer(state, TextLabelKind, defaultGlTextLabelRenderer);
        registerStandardGlTextureResolvers(state);
        glMaterial();
    }
  }

  public function useRichText():Void {
    switch (backend) {
      case DOM:
        registerRenderer(state, RichTextKind, defaultDomRichTextRenderer);
      case CANVAS | CAIRO:
        registerRenderer(state, RichTextKind, defaultCanvasRichTextRenderer);
      case GL:
        registerRenderer(state, RichTextKind, defaultGlRichTextRenderer);
        registerStandardGlTextureResolvers(state);
        glMaterial();
    }
  }

  // ---- frame ---------------------------------------------------------------

  /** False when nothing changed since the last frame; the caller should skip the draw. */
  public function prepare(root:Dynamic):Bool {
    return prepareScene2DRender(state, root);
  }

  public function draw(root:Dynamic):Void {
    switch (backend) {
      case DOM:
        renderDomBackground(state);
        renderDomScene2D(state, root);
      case CANVAS | CAIRO:
        renderCanvasBackground(state);
        renderCanvasScene2D(state, root);
      case GL:
        renderGlBackground(state);
        renderGlScene2D(state, root);
    }
  }

  // ---- internals -----------------------------------------------------------

  function resolvers():Dynamic {
    if (rasterResolvers == null) {
      rasterResolvers = createCanvasTextureResolvers();
      registerCanvasImageTextureResolver(rasterResolvers);
      registerCanvasBitmapTextureResolver(rasterResolvers);
    }
    return rasterResolvers;
  }

  // Registering the standard material twice is harmless but pointless; several use* calls want it.
  function glMaterial():Void {
    if (glMaterialReady) return;
    glMaterialReady = true;
    registerGlStandardMaterial(state);
  }
}
