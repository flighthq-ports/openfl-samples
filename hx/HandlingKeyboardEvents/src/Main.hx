// Haxe/Lime port of ts/src/handling-keyboard-events/app.ts.
//
// ts/ routes keys through createInputManager + attachKeyboardInput(input, window); Lime delivers them
// as onKeyDown/onKeyUp overrides, so the held-key set is filled from those instead. The movement is
// the same rate-based step ts/ uses, so it covers the same ground per second on any refresh rate.
package;

import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Sprite;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;

class Main extends Application {
  static inline final SPEED_PX_PER_SECOND = 5 * 60;

  var scale:Float = 1.0;
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var root:DisplayObject;
  var logo:Sprite;
  var held:Map<KeyCode, Bool> = new Map();

  public function new() {
    super();
  }

  override public function onWindowCreate():Void {
    App.setAppBackend(LimeApp.createLimeAppBackend(this));
    switch (window.context.type) {
      case DOM:
        RenderDom.init(window);
        scale = RenderDom.scale;
        drawFrame = RenderDom.render;
      case CANVAS:
        RenderCanvas.init(window);
        scale = RenderCanvas.scale;
        drawFrame = RenderCanvas.render;
      case CAIRO:
        RenderCairo.init(window);
        scale = RenderCairo.scale;
        drawFrame = RenderCairo.render;
      case OPENGL, OPENGLES, WEBGL:
        RenderGl.init(window);
        scale = RenderGl.scale;
        drawFrame = RenderGl.render;
      default:
        throw 'Unsupported Lime render context: ' + window.context.type;
    }
  }

  override public function onPreloadComplete():Void {
    root = createDisplayObject();
    root.scaleX = scale;
    root.scaleY = scale;

    logo = createSprite();
    logo.data.texture = createTexture(cast {dimension: '2d', source: LimeAssets.image('images/openfl_icon.png')});
    logo.x = 100;
    logo.y = 100;
    addNodeChild(root, logo);

    ready = true;
  }

  override public function onKeyDown(keyCode:KeyCode, modifier:KeyModifier):Void {
    held.set(keyCode, true);
  }

  override public function onKeyUp(keyCode:KeyCode, modifier:KeyModifier):Void {
    held.remove(keyCode);
  }

  override public function update(deltaTime:Int):Void {
    if (!ready) return;
    final step = SPEED_PX_PER_SECOND * (deltaTime / 1000);
    if (held.exists(KeyCode.DOWN)) logo.y += step;
    if (held.exists(KeyCode.LEFT)) logo.x -= step;
    if (held.exists(KeyCode.RIGHT)) logo.x += step;
    if (held.exists(KeyCode.UP)) logo.y -= step;
    invalidateNodeLocalTransform(logo);
  }

  override public function render(context:RenderContext):Void {
    if (!ready || root == null) return;
    if (!drawFrame(root)) window.onRender.cancel();
  }
}
