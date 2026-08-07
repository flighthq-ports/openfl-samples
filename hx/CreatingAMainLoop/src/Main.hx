// Haxe/Lime port of ts/src/creating-a-main-loop (app.ts + render.webgl.ts).
//
// ts/ calls startApplicationLoop(app), which drives itself from requestAnimationFrame. Lime already
// owns the frame, so the Flight Application is stepped explicitly from Lime's `update` override with
// stepApplicationLoop(app, deltaTime) — the same signals fire, with Lime as the clock. Drawing stays
// in Lime's `render` override, because that is the only place the window's back buffer is live.
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Shape;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  var scale:Float = 1.0;
  // Bound once to the chosen backend's render function, the way ts/ has render.ts re-export exactly
  // one render.<backend>.ts. Lime chooses for us, so the pick is a switch on the context type.
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var root:DisplayObject;
  var square:Shape;
  var app:Dynamic;
  var speed:Float = 0.3;

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

    root = createDisplayObject();
    root.scaleX = scale;
    root.scaleY = scale;

    square = createShape();
    appendShapeBeginFill(square, 0x24afc4);
    appendShapeRectangle(square, 0, 0, 100, 100);
    square.y = 50;
    addNodeChild(root, square);

    app = createApplication();
    connectSignal(app.onUpdate, function(delta:Float) {
      if (square.x + 100 >= 800 || square.x < 0) speed *= -1;
      square.x += speed * delta;
      invalidateNodeLocalTransform(square);
    });

    ready = true;
  }

  override public function update(deltaTime:Int):Void {
    if (!ready) return;
    stepApplicationLoop(app, deltaTime);
  }

  override public function render(context:RenderContext):Void {
    if (!ready || root == null) return;
    // Nothing changed since the last frame: skip the draw and cancel the present, so Lime does not
    // flip to a never-drawn back buffer.
    if (!drawFrame(root)) window.onRender.cancel();
  }
}
