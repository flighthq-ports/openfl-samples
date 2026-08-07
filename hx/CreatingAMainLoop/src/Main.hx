// Haxe/Lime port of ts/src/creating-a-main-loop (app.ts + render.webgl.ts).
//
// ts/ calls startApplicationLoop(app), which drives itself from requestAnimationFrame. Lime already
// owns the frame, so the Flight Application is stepped explicitly from Lime's `update` override with
// stepApplicationLoop(app, deltaTime) — the same signals fire, with Lime as the clock. Drawing stays
// in Lime's `render` override, because that is the only place the window's back buffer is live.
import LimeCanvas.CairoCanvas;
import LimeCanvas.GlCanvas;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Shape;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  var scale:Float = 1.0;
  var renderState:Dynamic;
  var usingCairo = false;
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
      case CAIRO:
        usingCairo = true;
      case OPENGL, OPENGLES, WEBGL:
      default:
        throw 'Flight samples require an OpenGL/WebGL or cairo render context.';
    }
    scale = window.scale;

    if (usingCairo) {
      renderState = createCanvasRenderState(new CairoCanvas(window), {
        pixelRatio: scale,
        sceneGraphSyncPolicy: 'requiresInvalidation',
        backgroundColor: 0xffffffff,
      });
      registerRenderer(renderState, ShapeKind, defaultCanvasShapeRenderer);
      registerCanvasShapeCommands(renderState, defaultCanvasShapeCommands);
    } else {
      renderState = createGlRenderState(new GlCanvas(window), {
        pixelRatio: scale,
        sceneGraphSyncPolicy: 'requiresInvalidation',
        backgroundColor: 0xffffffff,
      });
      registerRenderer(renderState, ShapeKind, defaultGlShapeRenderer);
      registerGlShapeCommands(renderState, defaultGlShapeCommands);
      registerGlShapeRasterizer(renderState, createCanvasShapeRasterizer(createCanvasTextureResolvers()));
      registerGlStandardMaterial(renderState);
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
    if (!prepareScene2DRender(renderState, root)) {
      window.onRender.cancel();
      return;
    }
    if (usingCairo) {
      renderCanvasBackground(renderState);
      renderCanvasScene2D(renderState, root);
    } else {
      renderGlBackground(renderState);
      renderGlScene2D(renderState, root);
    }
  }
}
