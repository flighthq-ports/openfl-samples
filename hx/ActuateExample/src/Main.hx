// Haxe/Lime port of ts/src/actuate-example/app.ts.
//
// ts/ drives the loop itself, calling stepApplicationLoop with a performance.now() delta from inside
// requestAnimationFrame. Lime owns the frame, so that same step happens in update(deltaTime).
package;

import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Shape;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  static inline final STAGE_WIDTH = 800;
  static inline final STAGE_HEIGHT = 600;
  static inline final CIRCLE_COUNT = 80;
  static inline final MIN_RADIUS = 25;
  static inline final MAX_RADIUS = 60;
  static inline final MIN_DURATION = 1500;
  static inline final MAX_DURATION = 6000;
  static inline final MAX_START_DELAY = 10000;
  static inline final FRAME_DELTA = 1000 / 30;

  var scale:Float = 1.0;
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var manager:Dynamic;
  var root:DisplayObject;
  var app:Dynamic;

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

    manager = createTweenManager();
    root = createDisplayObject();
    root.scaleX = scale;
    root.scaleY = scale;

    for (_ in 0...CIRCLE_COUNT) {
      final delay = Math.max(FRAME_DELTA, Math.random() * MAX_START_DELAY);
      final timer = createTweenTimer(manager, delay);
      connectSignal(timer.onComplete, function() {
        animateCircle(createCircle());
      });
    }

    app = createApplication();
    connectSignal(app.onUpdate, function(delta:Float) updateTweens(manager, delta));

    ready = true;
  }

  function animateCircle(circle:Shape):Void {
    final duration = MIN_DURATION + Math.random() * (MAX_DURATION - MIN_DURATION);
    final targetX = Math.random() * STAGE_WIDTH;
    final targetY = Math.random() * STAGE_HEIGHT;
    final tween = createTween(manager, circle, duration, {x: targetX, y: targetY}, {ease: easeOutQuadratic});
    connectSignal(tween.onComplete, function() animateCircle(circle));
    connectSignal(tween.onUpdate, function() invalidateNodeLocalTransform(circle));
  }

  function createCircle():Shape {
    final radius = MIN_RADIUS + Math.random() * (MAX_RADIUS - MIN_RADIUS);
    final circle = createShape();

    appendShapeBeginFill(circle, Math.floor(Math.random() * 0xffffff));
    appendShapeCircle(circle, 0, 0, radius);
    appendShapeEndFill(circle);

    circle.alpha = 0.2 + Math.random() * 0.6;
    circle.x = Math.random() * STAGE_WIDTH;
    circle.y = Math.random() * STAGE_HEIGHT;
    invalidateNodeLocalTransform(circle);

    addNodeChildAt(root, circle, 0);
    return circle;
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
