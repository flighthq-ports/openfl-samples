// Cairo — Lime's native software context, from a window with hardware="false".
//
// Kept apart from RenderCanvas even though it currently calls the same Flight entry points, because
// cairo-specific entry points are being commissioned upstream. When they land, only this file
// changes; the html5 canvas path stays where it is.
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
    #else
    throw 'The cairo backend needs a native Lime build with cairo support.';
    #end
  }

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
}
