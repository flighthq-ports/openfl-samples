// Cairo -- Lime's native software context, from a window with hardware="false".
//
// Kept apart from RenderCanvas even though it currently calls the same Flight entry points,
// because cairo-specific entry points are being commissioned upstream.
package;

import LimeCanvas.CairoCanvas;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import lime.ui.Window;

class RenderCairo {
  public static var state:Dynamic;
  public static var scale:Float = 1;

  public static function init(window:Window):Void {
    #if (lime && !js && lime_cairo)
    scale = window.scale;
    state = createCanvasRenderState(new CairoCanvas(window), {
      pixelRatio: scale,
      sceneGraphSyncPolicy: 'requiresInvalidation',
      backgroundColor: 0xffffffff,
    });
    registerRenderer(state, ShapeKind, defaultCanvasShapeRenderer);
    registerCanvasShapeCommands(state, defaultCanvasShapeCommands);
    registerRenderer(state, SpriteKind, defaultCanvasSpriteRenderer);
    registerCanvasImageTextureResolver(getCanvasRenderStateTextureResolvers(state));
    registerCanvasBitmapTextureResolver(getCanvasRenderStateTextureResolvers(state));
    registerRenderer(state, TextLabelKind, defaultCanvasTextLabelRenderer);
    #else
    throw 'The cairo backend needs a native Lime build with cairo support.';
    #end
  }

  // ts/ returns void here; this returns whether anything was drawn, so the caller can cancel Lime's
  // present on a skipped frame instead of flipping to a never-drawn back buffer.
  public static function render(root:DisplayObject):Bool {
    #if (lime && !js && lime_cairo)
    if (!prepareScene2DRender(state, root)) return false;
    renderCanvasBackground(state);
    renderCanvasScene2D(state, root);
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
