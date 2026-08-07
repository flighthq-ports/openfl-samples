// the render.<backend>.ts of ts/src/AddingText.
//
// html5 only — Lime hands out a DOM context on `lime build html5 -Ddom`. The body is guarded so a
// neko build does not drag the DOM backend in behind a branch it can never take.
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
    // Lime's DOM context is the <div> it renders into. Flight positions its elements inside that
    // host, so it has to be a positioned box of known size.
    final container:Dynamic = window.context.dom;
    container.style.position = 'relative';
    container.style.width = window.width + 'px';
    container.style.height = window.height + 'px';
    container.style.overflow = 'hidden';

    state = createDomRenderState(container, {
      sceneGraphSyncPolicy: 'requiresInvalidation',
      backgroundColor: 0xffffffff,
    });
    registerRenderer(state, TextLabelKind, defaultDomTextLabelRenderer);
    #else
    throw 'The DOM backend is html5 only.';
    #end
  }

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
}
