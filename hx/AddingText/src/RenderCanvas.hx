// the render.<backend>.ts of ts/src/AddingText.
//
// html5 only — Lime hands out a 2D canvas context on `lime build html5 -Dcanvas`, or when the window
// asks for hardware="false". Cairo is the native software context and gets its own file.
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
    // The 2D context's own canvas element is what createCanvasRenderState wants: it calls
    // getContext('2d') on it and reads width/height off it.
    final context2D:Dynamic = window.context.canvas2D;
    state = createCanvasRenderState(context2D.canvas, {
      pixelRatio: scale,
      sceneGraphSyncPolicy: 'requiresInvalidation',
      backgroundColor: 0xffffffff,
    });
    registerRenderer(state, TextLabelKind, defaultCanvasTextLabelRenderer);
    #else
    throw 'The canvas backend is html5 only.';
    #end
  }

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
