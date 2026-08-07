// Haxe/Lime port of ts/src/handling-mouse-events/app.ts.
//
// ts/ routes the pointer through createInputManager + attachPointerInput(input, container); Lime
// delivers the same three events as onMouseDown/onMouseMove/onMouseUp overrides. The one thing that
// does not carry over is `container.style.cursor` — that is a DOM property, so the hover cursor is
// set through Lime's own window.cursor instead.
package;

import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Shape;
import flighthq.types.Sprite;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.MouseButton;

class Main extends Application {
  var scale:Float = 1.0;
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var manager:Dynamic;
  var root:DisplayObject;
  var destination:Shape;
  var logo:Sprite;
  var app:Dynamic;

  var imageWidth:Float = 0;
  var imageHeight:Float = 0;

  var dragging = false;
  var tweening = false;
  var offsetX:Float = 0;
  var offsetY:Float = 0;

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
    final image = LimeAssets.image('images/openfl_icon.png');
    imageWidth = image.width;
    imageHeight = image.height;

    manager = createTweenManager();
    root = createDisplayObject();
    root.scaleX = scale;
    root.scaleY = scale;

    destination = createShape();
    appendShapeLineStyle(destination, 1, 0xcccccc);
    appendShapeBeginFill(destination, 0xf5f5f5);
    appendShapeRectangle(destination, 0, 0, imageWidth + 10, imageHeight + 10);
    destination.x = 300;
    destination.y = 95;
    addNodeChild(root, destination);

    logo = createSprite();
    logo.data.texture = createTexture(cast {dimension: '2d', source: image});
    logo.x = 100;
    logo.y = 100;
    addNodeChild(root, logo);

    app = createApplication();
    connectSignal(app.onUpdate, function(delta:Float) updateTweens(manager, delta));

    ready = true;
  }

  function hitTestLogo(px:Float, py:Float):Bool {
    return px >= logo.x && px <= logo.x + imageWidth && py >= logo.y && py <= logo.y + imageHeight;
  }

  override public function onMouseDown(x:Float, y:Float, button:MouseButton):Void {
    if (!ready || tweening) return;
    if (!hitTestLogo(x, y)) return;
    dragging = true;
    offsetX = logo.x - x;
    offsetY = logo.y - y;
  }

  override public function onMouseMove(x:Float, y:Float):Void {
    if (!ready) return;
    if (dragging) {
      logo.x = x + offsetX;
      logo.y = y + offsetY;
      invalidateNodeLocalTransform(logo);
    } else if (!tweening) {
      // ts/ sets container.style.cursor; the Lime equivalent is the window's own cursor.
      window.cursor = hitTestLogo(x, y) ? POINTER : DEFAULT;
    }
  }

  override public function onMouseUp(x:Float, y:Float, button:MouseButton):Void {
    if (!ready) return;
    dragging = false;
    final hit = x >= destination.x
      && x <= destination.x + imageWidth + 10
      && y >= destination.y
      && y <= destination.y + imageHeight + 10;
    if (hit) {
      tweening = true;
      final tween = createTween(manager, logo, 1000, {x: destination.x + 5, y: destination.y + 5});
      connectSignal(tween.onUpdate, function() invalidateNodeLocalTransform(logo));
      connectSignal(tween.onComplete, function() tweening = false);
    }
  }

  override public function update(deltaTime:Int):Void {
    if (!ready) return;
    stepApplicationLoop(app, deltaTime);
  }

  override public function render(context:RenderContext):Void {
    if (!ready || root == null) return;
    if (!drawFrame(root)) window.onRender.cancel();
  }
}
