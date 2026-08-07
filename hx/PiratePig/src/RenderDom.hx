// ts/src/PiratePig: render.dom.ts. html5 only.
package;

import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import lime.ui.Window;

class RenderDom {
  public static var state:Dynamic;
  public static var scale:Float = 1;

  public static function init(window:Window):Void {
    #if js
    scale = window.scale;
    // Lime's DOM context is the <div> it renders into; Flight positions its elements inside
    // that host, so it has to be a positioned box of known size.
    final container:Dynamic = window.context.dom;
    container.style.position = 'relative';
    container.style.width = window.width + 'px';
    container.style.height = window.height + 'px';
    container.style.overflow = 'hidden';
    state = createDomRenderState(container, {
      sceneGraphSyncPolicy: 'requiresInvalidation',
      backgroundColor: 0xffffffff,
    });
    registerRenderer(state, ShapeKind, defaultDomShapeRenderer);
    registerCanvasShapeCommands(state, defaultCanvasShapeCommands);
    // The DOM shape renderer draws no paths itself: it allocates a <canvas> per Shape and hands the
    // commands to the registered rasterizer. Without this, every Shape silently draws nothing.
    registerDomShapeRasterizer(state, createCanvasShapeRasterizer(createCanvasTextureResolvers()));
    registerRenderer(state, SpriteKind, defaultDomSpriteRenderer);
    registerDomImageTextureResolver(state);
    registerDomBitmapTextureResolver(state);
    registerRenderer(state, TextLabelKind, defaultDomTextLabelRenderer);
    #else
    throw 'The DOM backend is html5 only.';
    #end
  }

  // ts/ returns void here; this returns whether anything was drawn, so the caller can cancel Lime's
  // present on a skipped frame instead of flipping to a never-drawn back buffer.
  public static function render(root:DisplayObject):Bool {
    #if js
    if (!prepareScene2DRender(state, root)) return false;
    renderDomBackground(state);
    renderDomScene2D(state, root);
    return true;
    #else
    return false;
    #end
  }

  // ts/src/pirate-pig/render.webgl.ts bakes the score panel's blur into an offscreen pass
  // (createBlurEffect -> computeRenderEffectPadding -> a cached render target re-baked on resize).
  // That is not ported yet, so the panel draws unfiltered here and the refresh hook is a no-op.
  // ts/'s own DOM backend stubs it the same way.
  public static function applyBackgroundBlur(node:Dynamic):Void->Void {
    return function() {};
  }

}
