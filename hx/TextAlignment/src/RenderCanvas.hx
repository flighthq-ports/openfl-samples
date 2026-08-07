// ts/src/TextAlignment: render.canvas.ts. html5 only; cairo is the native software context.
package;

import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import lime.ui.Window;

class RenderCanvas {
  public static var state:Dynamic;
  public static var scale:Float = 1;

  public static function init(window:Window):Void {
    #if js
    scale = window.scale;
    // The 2D context's own canvas element is what createCanvasRenderState wants.
    final context2D:Dynamic = window.context.canvas2D;
    state = createCanvasRenderState(context2D.canvas, {
      pixelRatio: scale,
      sceneGraphSyncPolicy: 'requiresInvalidation',
      backgroundColor: 0xa0a0a0ff,
    });
    registerRenderer(state, RichTextKind, defaultCanvasRichTextRenderer);
    registerRenderer(state, SpriteKind, defaultCanvasSpriteRenderer);
    registerCanvasImageTextureResolver(getCanvasRenderStateTextureResolvers(state));
    registerCanvasBitmapTextureResolver(getCanvasRenderStateTextureResolvers(state));
    #else
    throw 'The canvas backend is html5 only.';
    #end
  }

  // ts/ returns void here; this returns whether anything was drawn, so the caller can cancel Lime's
  // present on a skipped frame instead of flipping to a never-drawn back buffer.
  public static function render(root:DisplayObject):Bool {
    #if js
    if (!prepareScene2DRender(state, root)) return false;
    renderCanvasBackground(state);
    renderCanvasScene2D(state, root);
    return true;
    #else
    return false;
    #end
  }
}
