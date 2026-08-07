// Haxe/Lime port of ts/src/world-clock/app.ts.
//
// ts/ calls startApplicationLoop(app), which drives itself off requestAnimationFrame. Lime owns the
// frame here, so the Flight Application is stepped from Lime's update() and the draw stays in
// render(), the only place the window's back buffer is live.
package;

import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Shape;
import flighthq.types.TextLabel;
import lime.app.Application;
import lime.graphics.RenderContext;

private typedef Clock = {
  var clock:DisplayObject;
  var center:Shape;
  var hourHand:Shape;
  var minuteHand:Shape;
  var secondHand:Shape;
  var offset:Int;
}

class Main extends Application {
  static inline final RADIUS = 50;

  var scale:Float = 1.0;
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var root:DisplayObject;
  var clocks:Array<Clock> = [];
  var app:Dynamic;
  var lastSecond = -1;

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

    clocks = [
      createClock('New York', 0xcc0000, -4, 10, 10),
      createClock('London', 0x009900, 1, 130, 10),
      createClock('Tokyo', 0x0000cc, 9, 250, 10),
    ];

    app = createApplication();
    connectSignal(app.onUpdate, function(_:Float) {
      final second = Date.now().getSeconds();
      if (second != lastSecond) {
        lastSecond = second;
        updateClocks();
      }
    });

    updateClocks();
    ready = true;
  }

  function createClock(labelText:String, color:Int, offset:Int, x:Float, y:Float):Clock {
    final clock = createDisplayObject();
    final face = createShape();
    final hourHand = createShape();
    final minuteHand = createShape();
    final secondHand = createShape();
    final center = createShape();
    final label:TextLabel = createTextLabel();

    appendShapeLineStyle(face, RADIUS / 5, color);
    appendShapeBeginFill(face, color, 0.25);
    appendShapeCircle(face, RADIUS, RADIUS, RADIUS);
    addNodeChild(clock, face);

    label.data.text = labelText;
    label.data.textFormat = cast {align: 'center', color: 0x000000, font: 'sans-serif', size: 18};
    label.data.width = RADIUS * 2;
    label.x = 0;
    label.y = RADIUS * 2 + 4;
    addNodeChild(clock, label);

    addNodeChild(clock, hourHand);
    addNodeChild(clock, minuteHand);
    addNodeChild(clock, secondHand);
    addNodeChild(clock, center);

    clock.x = x;
    clock.y = y;
    invalidateNodeLocalTransform(clock);
    addNodeChild(root, clock);

    return {
      clock: clock,
      center: center,
      hourHand: hourHand,
      minuteHand: minuteHand,
      secondHand: secondHand,
      offset: offset,
    };
  }

  function updateClocks():Void {
    final now = Date.now();
    for (entry in clocks) updateClock(entry, offsetDate(now, entry.offset));
  }

  // ts/ shifts a Date by a whole-hour UTC offset; Haxe's Date has no arithmetic, so the shift is done
  // on the epoch value and read back through the local getters the same way.
  static function offsetDate(date:Date, offset:Int):Date {
    final utc = date.getTime() + date.getTimezoneOffset() * 60 * 1000;
    return Date.fromTime(utc + offset * 60 * 60 * 1000);
  }

  function updateClock(entry:Clock, date:Date):Void {
    final shortHand = RADIUS / 2;
    final longHand = (RADIUS * 3) / 4;

    clearShapeCommands(entry.hourHand);
    clearShapeCommands(entry.minuteHand);
    clearShapeCommands(entry.secondHand);
    clearShapeCommands(entry.center);

    var hours = date.getHours();
    if (hours >= 12) hours -= 12;
    final hourAngle = (hours / 12) * Math.PI * 2 - Math.PI / 2;
    final minuteAngle = (date.getMinutes() / 60) * Math.PI * 2 - Math.PI / 2;
    final secondAngle = (date.getSeconds() / 60) * Math.PI * 2 - Math.PI / 2;

    appendShapeLineStyle(entry.hourHand, 5, 0x000000);
    appendShapeMoveTo(entry.hourHand, RADIUS, RADIUS);
    appendShapeLineTo(entry.hourHand, RADIUS + Math.cos(hourAngle) * shortHand, RADIUS + Math.sin(hourAngle) * shortHand);

    appendShapeLineStyle(entry.minuteHand, 4, 0x000000);
    appendShapeMoveTo(entry.minuteHand, RADIUS, RADIUS);
    appendShapeLineTo(entry.minuteHand, RADIUS + Math.cos(minuteAngle) * longHand,
      RADIUS + Math.sin(minuteAngle) * longHand);

    appendShapeLineStyle(entry.secondHand, 2, 0xff0000);
    appendShapeMoveTo(entry.secondHand, RADIUS, RADIUS);
    appendShapeLineTo(entry.secondHand, RADIUS + Math.cos(secondAngle) * longHand,
      RADIUS + Math.sin(secondAngle) * longHand);

    appendShapeBeginFill(entry.center, 0xff0000);
    appendShapeCircle(entry.center, RADIUS, RADIUS, 4);

    invalidateNodeRender(entry.hourHand);
    invalidateNodeRender(entry.minuteHand);
    invalidateNodeRender(entry.secondHand);
    invalidateNodeRender(entry.center);
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
