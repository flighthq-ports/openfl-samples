// Haxe/Lime port of ts/src/drawing-shapes (app.ts + render.webgl.ts), written against the generated
// Flight Haxe surface (flighthq.*). The scene is translated statement for statement; only the browser
// glue differs — ts/ builds its render state in a `render.<backend>.ts` module and drives the frame
// with requestAnimationFrame, whereas here the render state is built in `onWindowCreate` over Lime's
// window and the frame is Lime's own `render` override.
import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Shape;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  // ts/ reads `window.devicePixelRatio || 1`; Lime exposes the same thing as `window.scale`.
  var scale:Float = 1.0;
  var renderer:Renderer;
  var ready = false;

  var main:DisplayObject;

  public function new() {
    super();
  }

  override public function onWindowCreate():Void {
    App.setAppBackend(LimeApp.createLimeAppBackend(this));
    renderer = new Renderer(window, 0xffffffff);
    renderer.useShapes();
    scale = renderer.scale;

    main = createDisplayObject();
    main.scaleX = scale;
    main.scaleY = scale;

    // ── Row 1: primitives ──────────────────────────────────────────────────

    final square = createShape();
    appendShapeBeginFill(square, 0x24afc4);
    appendShapeRectangle(square, 0, 0, 100, 100);
    place(square, 20, 20);

    final rectangle = createShape();
    appendShapeBeginFill(rectangle, 0x24afc4);
    appendShapeRectangle(rectangle, 0, 0, 120, 100);
    place(rectangle, 140, 20);

    final circle = createShape();
    appendShapeBeginFill(circle, 0x24afc4);
    appendShapeCircle(circle, 50, 50, 50);
    place(circle, 280, 20);

    final ellipse = createShape();
    appendShapeBeginFill(ellipse, 0x24afc4);
    appendShapeEllipse(ellipse, 0, 0, 120, 100);
    place(ellipse, 400, 20);

    final roundSquare = createShape();
    appendShapeBeginFill(roundSquare, 0x24afc4);
    appendShapeRoundRectangle(roundSquare, 0, 0, 100, 100, 40, 40);
    place(roundSquare, 540, 20);

    // ── Row 2: polygons ────────────────────────────────────────────────────

    final triangle = createShape();
    appendShapeBeginFill(triangle, 0x24afc4);
    appendShapeMoveTo(triangle, 0, 100);
    appendShapeLineTo(triangle, 50, 0);
    appendShapeLineTo(triangle, 100, 100);
    appendShapeLineTo(triangle, 0, 100);
    place(triangle, 20, 150);

    final pentagon = createShape();
    appendShapeBeginFill(pentagon, 0x24afc4);
    drawPolygon(pentagon, 50, 50, 50, 5);
    place(pentagon, 145, 150);

    final hexagon = createShape();
    appendShapeBeginFill(hexagon, 0x24afc4);
    drawPolygon(hexagon, 50, 50, 50, 6);
    place(hexagon, 270, 150);

    final heptagon = createShape();
    appendShapeBeginFill(heptagon, 0x24afc4);
    drawPolygon(heptagon, 50, 50, 50, 7);
    place(heptagon, 395, 150);

    final octagon = createShape();
    appendShapeBeginFill(octagon, 0x24afc4);
    drawPolygon(octagon, 50, 50, 50, 8);
    place(octagon, 520, 150);

    // ── Row 3: lines and curves ────────────────────────────────────────────

    final line = createShape();
    appendShapeLineStyle(line, 10, 0x24afc4);
    appendShapeLineTo(line, 755, 0);
    place(line, 20, 280);

    final curve = createShape();
    appendShapeLineStyle(curve, 10, 0x24afc4);
    appendShapeCurveTo(curve, 327.5, -50, 755, 0);
    place(curve, 20, 340);

    ready = true;
  }

  function place(shape:Shape, x:Float, y:Float):Void {
    shape.x = x;
    shape.y = y;
    invalidateNodeLocalTransform(shape);
    addNodeChild(main, shape);
  }

  function drawPolygon(g:Shape, x:Float, y:Float, radius:Float, sides:Int):Void {
    final step = (Math.PI * 2) / sides;
    final start = 0.5 * Math.PI;
    appendShapeMoveTo(g, Math.cos(start) * radius + x, -Math.sin(start) * radius + y);
    for (i in 0...sides) {
      appendShapeLineTo(g, Math.cos(start + step * i) * radius + x, -Math.sin(start + step * i) * radius + y);
    }
  }

  // ts/ calls render(main) from its requestAnimationFrame loop; Lime drives the same call here.
  override public function render(context:RenderContext):Void {
    if (!ready || main == null) return;
    // Nothing changed since the last frame: skip the draw and cancel the present, so Lime does not
    // flip to a never-drawn back buffer. The `requiresInvalidation` sync policy is what makes this
    // the common case for a static scene like this one.
    if (!renderer.prepare(main)) {
      window.onRender.cancel();
      return;
    }
    renderer.draw(main);
  }
}
