// Haxe/Lime port of ts/src/simple-box2d/app.ts.
//
// The physics carries over unchanged, including the fixed timestep: the simulation advances in whole
// 1/30 s steps at wall-clock rate whatever the refresh rate is, so the solver only ever sees the step
// size it was tuned for. ts/ gets that from startApplicationLoop's own accumulator; that accumulator
// lives inside the loop's rAF tick, so driving the loop from Lime means owning it here (see update).
//
// The drag handlers move from container pointer listeners onto Lime's onMouseDown/Move/Up. Lime
// delivers window-space coordinates directly, so ts/'s getBoundingClientRect correction is not needed.
package;

import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Shape;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.MouseButton;

private enum Outline {
  Box(width:Float, height:Float);
  Circle(radius:Float);
}

private typedef BodyView = {
  var body:Dynamic;
  var node:Shape;
  var outline:Outline;
  var color:Int;
  var spawnX:Float;
  var spawnY:Float;
}

class Main extends Application {
  static inline final PIXELS_PER_METRE = 160;
  static inline final PHYSICS_SCALE = 1 / PIXELS_PER_METRE;
  static inline final GRAVITY_M_PER_S2 = 9.8;
  static inline final PHYSICS_STEP_SECONDS = 1 / 30;
  static inline final PHYSICS_STEP_MS = PHYSICS_STEP_SECONDS * 1000;
  static final RAD_TO_DEG = 180 / Math.PI;

  static inline final STATIC_COLOR = 0x7fe57f;
  static inline final DYNAMIC_COLOR = 0xe5b2b2;
  static inline final SLEEPING_COLOR = 0x999999;
  static inline final FILL_ALPHA = 0.5;
  static inline final LINE_THICKNESS = 1;

  static inline final DENSITY = 1;
  static inline final FRICTION = 0.2;
  static inline final RESTITUTION = 0;

  static inline final DRAG_FORCE_PER_MASS = 1000;
  static inline final DRAG_FREQUENCY_HZ = 5;
  static inline final DRAG_DAMPING_RATIO = 0.7;

  static inline final STAGE_WIDTH = 800;
  static inline final STAGE_HEIGHT = 600;
  static inline final LOST_MARGIN = 200;

  // 250 ms is the clamp ts/'s loop applies to a single frame; 250 / 33.33 is 7.5 steps, so 8 is the
  // smallest cap that never discards time a clamped frame legitimately earned.
  static inline final MAX_DELTA_MS = 250;
  static inline final MAX_STEPS_PER_FRAME = 8;

  var scale:Float = 1.0;
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var root:DisplayObject;
  var world:Dynamic;
  var views:Array<BodyView> = [];
  var query:Dynamic;
  var drag:Dynamic = null;
  var app:Dynamic;
  var fixedAccumulator:Float = 0;

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

    // Gravity is positive-y because the scene keeps the source demo's screen-space axis, where y
    // grows downward. Flight's own default points the other way, for a y-up world.
    world = createPhysics2DWorld(0, GRAVITY_M_PER_S2);
    registerPhysics2DJointSolver(world, Physics2DMouseJointKind, physics2DMouseJointSolver);

    createBox(400, 480, 800, 160, false);
    createBox(400, 160, 160, 160, true);
    createCircle(160, 160, 80, false);
    createCircle(640, 160, 80, true);

    query = createPhysics2DQueryResult();

    app = createApplication();
    connectSignal(app.onUpdate, function(_:Float) {
      for (view in views) {
        resetIfLost(view);
        place(view);
        final color = bodyColor(view.body);
        if (color != view.color) paint(view, color);
      }
    });

    ready = true;
  }

  function paint(view:BodyView, color:Int):Void {
    final node = view.node;
    clearShapeCommands(node);
    appendShapeLineStyle(node, LINE_THICKNESS, color);
    appendShapeBeginFill(node, color, FILL_ALPHA);

    switch (view.outline) {
      case Circle(radius):
        appendShapeCircle(node, 0, 0, radius);
        appendShapeEndFill(node);
        // b2DebugDraw lays the body's x axis across the disc, the only way rotation reads on a circle.
        appendShapeMoveTo(node, 0, 0);
        appendShapeLineTo(node, radius, 0);
      case Box(width, height):
        appendShapeRectangle(node, -width / 2, -height / 2, width, height);
        appendShapeEndFill(node);
    }

    view.color = color;
  }

  function bodyColor(body:Dynamic):Int {
    if (body.type == 'static') return STATIC_COLOR;
    return body.sleeping ? SLEEPING_COLOR : DYNAMIC_COLOR;
  }

  function addView(body:Dynamic, outline:Outline):Void {
    final view:BodyView = {
      body: body,
      node: createShape(),
      outline: outline,
      color: 0,
      spawnX: body.x,
      spawnY: body.y,
    };
    addNodeChild(root, view.node);
    paint(view, bodyColor(body));
    place(view);
    views.push(view);
  }

  function place(view:BodyView):Void {
    view.node.x = view.body.x / PHYSICS_SCALE;
    view.node.y = view.body.y / PHYSICS_SCALE;
    view.node.rotation = view.body.angle * RAD_TO_DEG;
    invalidateNodeLocalTransform(view.node);
  }

  function createBox(x:Float, y:Float, width:Float, height:Float, dynamicBody:Bool):Dynamic {
    final body = createRigidBody2D(dynamicBody ? 'dynamic' : 'static', x * PHYSICS_SCALE, y * PHYSICS_SCALE);
    body.colliders.push(createPhysics2DCollider({
      kind: 'obb',
      x: 0,
      y: 0,
      halfW: (width / 2) * PHYSICS_SCALE,
      halfH: (height / 2) * PHYSICS_SCALE,
      rotation: 0,
    }, {density: DENSITY, friction: FRICTION, restitution: RESTITUTION}));
    // Mass is derived from the colliders when the body joins the world, so they have to exist first.
    addPhysics2DBody(world, body);
    addView(body, Box(width, height));
    return body;
  }

  function createCircle(x:Float, y:Float, radius:Float, dynamicBody:Bool):Dynamic {
    final body = createRigidBody2D(dynamicBody ? 'dynamic' : 'static', x * PHYSICS_SCALE, y * PHYSICS_SCALE);
    body.colliders.push(createPhysics2DCollider({kind: 'circle', x: 0, y: 0, radius: radius * PHYSICS_SCALE},
      {density: DENSITY, friction: FRICTION, restitution: RESTITUTION}));
    addPhysics2DBody(world, body);
    addView(body, Circle(radius));
    return body;
  }

  static function isLost(x:Float, y:Float):Bool {
    return x < -LOST_MARGIN || x > STAGE_WIDTH + LOST_MARGIN || y < -LOST_MARGIN || y > STAGE_HEIGHT + LOST_MARGIN;
  }

  function resetIfLost(view:BodyView):Void {
    if (view.body.type != 'dynamic') return;
    // The body on the end of the cursor is exempt: it is only out there because it is being held.
    if (drag != null && drag.bodyB == view.body.index) return;
    if (!isLost(view.body.x / PHYSICS_SCALE, view.body.y / PHYSICS_SCALE)) return;

    view.body.x = view.spawnX;
    view.body.y = view.spawnY;
    view.body.angle = 0;
    view.body.velocityX = 0;
    view.body.velocityY = 0;
    view.body.angularVelocity = 0;
    wakePhysics2DBody(view.body);
  }

  function bodyAt(worldX:Float, worldY:Float):Dynamic {
    queryPhysics2DPoint(world, worldX, worldY, query);
    var i = 0;
    while (i < query.hitCount) {
      final body = query.hits[i].body;
      if (body.type == 'dynamic') return body;
      i++;
    }
    return null;
  }

  // Lime hands over window-space coordinates, so this is ts/'s pointerWorld without the
  // getBoundingClientRect correction a DOM listener needs.
  inline function pointerWorldX(x:Float):Float return (x / scale) * PHYSICS_SCALE;

  inline function pointerWorldY(y:Float):Float return (y / scale) * PHYSICS_SCALE;

  override public function onMouseDown(x:Float, y:Float, button:MouseButton):Void {
    if (!ready) return;
    final px = pointerWorldX(x);
    final py = pointerWorldY(y);
    final body = bodyAt(px, py);
    if (body == null) return;

    // A sleeping body is skipped by the joint solver, so grabbing one has to wake it first.
    wakePhysics2DBody(body);

    final cos = Math.cos(body.angle);
    final sin = Math.sin(body.angle);
    final offsetX = px - body.x;
    final offsetY = py - body.y;

    // The anchor is given in the body's own frame, so the grab point has to be rotated out of world
    // space by the body's current angle.
    final joint = createPhysics2DMouseJoint({
      body: body.index,
      targetX: px,
      targetY: py,
      maxForce: DRAG_FORCE_PER_MASS * body.mass,
      localAnchorX: offsetX * cos + offsetY * sin,
      localAnchorY: -offsetX * sin + offsetY * cos,
      frequencyHz: DRAG_FREQUENCY_HZ,
      dampingRatio: DRAG_DAMPING_RATIO,
    });

    addPhysics2DJoint(world, joint);
    drag = joint;
  }

  override public function onMouseMove(x:Float, y:Float):Void {
    if (drag == null) return;
    drag.targetX = pointerWorldX(x);
    drag.targetY = pointerWorldY(y);
  }

  override public function onMouseUp(x:Float, y:Float, button:MouseButton):Void {
    endDrag();
  }

  function endDrag():Void {
    if (drag == null) return;
    removePhysics2DJoint(world, drag);
    drag = null;
  }

  // ts/ gets its fixed timestep from startApplicationLoop's own accumulator, via app.onFixedUpdate.
  // That accumulator lives inside the loop's rAF tick; stepApplicationLoop emits onUpdate/onRender
  // only, so driving the loop from Lime means owning the accumulator here. Same behaviour: the
  // simulation advances in whole 1/30 s steps at wall-clock rate whatever the refresh rate is.
  override public function update(deltaTime:Int):Void {
    if (!ready) return;

    // Clamp first, so a stall cannot bank an unbounded backlog, then spend the time in whole steps.
    fixedAccumulator += Math.min(deltaTime, MAX_DELTA_MS);
    var steps = 0;
    while (fixedAccumulator >= PHYSICS_STEP_MS && steps < MAX_STEPS_PER_FRAME) {
      fixedAccumulator -= PHYSICS_STEP_MS;
      steps++;
      stepPhysics2D(world, PHYSICS_STEP_SECONDS);
    }
    // Spiral-of-death guard: if catching up would take more than the cap, drop the backlog rather
    // than falling further behind every frame.
    if (steps >= MAX_STEPS_PER_FRAME) fixedAccumulator = 0;

    stepApplicationLoop(app, deltaTime);
  }

  override public function render(context:RenderContext):Void {
    if (!ready || root == null) return;
    if (!drawFrame(root)) window.onRender.cancel();
  }
}
