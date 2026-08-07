// Haxe/Lime port of ts/src/adding-animation/app.ts.
//
// The scene is built in onPreloadComplete, not onWindowCreate: Lime preloads assets asynchronously
// and only guarantees them once preloading finishes, so reading the image any earlier works on neko
// (synchronous loads) and comes back null in a browser.
package;

import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  static inline final STAGE_WIDTH = 800;
  static inline final STAGE_HEIGHT = 600;

  var scale:Float = 1.0;
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var manager:Dynamic;
  var main:DisplayObject;
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
  }

  override public function onPreloadComplete():Void {
    manager = createTweenManager();
    main = createDisplayObject();
    main.scaleX = scale;
    main.scaleY = scale;

    final container = createDisplayObject();
    final bitmap = createSprite();

    container.alpha = 0;
    container.scaleX = 0;
    container.scaleY = 0;
    container.x = STAGE_WIDTH / 2;
    container.y = STAGE_HEIGHT / 2;

    addNodeChild(container, bitmap);
    addNodeChild(main, container);

    final image = LimeAssets.image('images/openfl_logo.png');
    bitmap.data.texture = createTexture(cast {dimension: '2d', source: image});
    bitmap.x = -imageWidth(image) / 2;
    bitmap.y = -imageHeight(image) / 2;

    final alphaTween = createTween(manager, container, 3000, {alpha: 1}, {ease: easeOutQuadratic});
    final scaleTween = createTween(manager, container, 6000, {scaleX: 1, scaleY: 1},
      {delay: 600, ease: easeOutElastic});
    connectSignal(alphaTween.onUpdate, function() invalidateNodeRender(container));
    connectSignal(scaleTween.onUpdate, function() invalidateNodeLocalTransform(container));

    app = createApplication();
    connectSignal(app.onUpdate, function(delta:Float) updateTweens(manager, delta));

    ready = true;
  }

  static inline function imageWidth(image:Dynamic):Float return image.width;

  static inline function imageHeight(image:Dynamic):Float return image.height;

  override public function update(deltaTime:Int):Void {
    if (!ready) return;
    stepApplicationLoop(app, deltaTime);
  }

  override public function render(context:RenderContext):Void {
    if (!ready || main == null) return;
    if (!drawFrame(main)) window.onRender.cancel();
  }
}
