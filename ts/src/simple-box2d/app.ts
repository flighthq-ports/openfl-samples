import type { Physics2DMouseJoint, RigidBody2D, Shape } from '@flighthq/sdk';
import {
  addNodeChild,
  addPhysics2DBody,
  addPhysics2DJoint,
  appendShapeBeginFill,
  appendShapeCircle,
  appendShapeEndFill,
  appendShapeLineStyle,
  appendShapeLineTo,
  appendShapeMoveTo,
  appendShapeRectangle,
  clearShapeCommands,
  connectSignal,
  createApplication,
  createDisplayObject,
  createPhysics2DCollider,
  createPhysics2DMouseJoint,
  createPhysics2DQueryResult,
  createPhysics2DWorld,
  createRigidBody2D,
  createShape,
  createSignal,
  invalidateNodeLocalTransform,
  Physics2DMouseJointKind,
  physics2DMouseJointSolver,
  queryPhysics2DPoint,
  registerPhysics2DJointSolver,
  removePhysics2DJoint,
  startApplicationLoop,
  stepPhysics2D,
  wakePhysics2DBody,
} from '@flighthq/sdk';

import { container, render, scale } from './render';

// Pixels per metre — the one number that decides whether this reads as gravity or as a moon walk.
//
// Gravity below is 9.8 m/s², so a body's *screen* acceleration is 9.8 x PIXELS_PER_METRE. The source
// laid its scene out at 30 px/m on a 500x400 stage, which this port scaled 1.6x to the corpus-standard
// 800x600, giving 48 px/m. At that scale the falling crate is 160 px / 48 = 3.3 metres across and the
// stage is 16.7 m wide: correct gravity applied to objects the size of a small building, which is
// exactly what low gravity looks like. Big things really do fall slowly relative to their own size.
//
// 160 px/m instead makes the crate 1 m, the balls 0.5 m radius, the ground 5 m wide and the stage
// 5 x 3.75 m — Box2D's recommended range, and the scale the tuning constants below assume. On screen
// that is 1568 px/s² rather than 480, so the crate crosses its own height in 0.45 s instead of 0.82 s.
//
// This is a deliberate departure from the source's simulation: same solver, same gravity, different
// world scale. The picture is what was wrong, not the physics.
const PIXELS_PER_METRE = 160;
const PHYSICS_SCALE = 1 / PIXELS_PER_METRE;
const GRAVITY_M_PER_S2 = 9.8;
// The source's per-frame step, now expressed as a rate rather than a per-frame constant.
const PHYSICS_STEP_SECONDS = 1 / 30;
const PHYSICS_STEP_MS = PHYSICS_STEP_SECONDS * 1000;
const RAD_TO_DEG = 180 / Math.PI;

// b2DebugDraw's palette, so this column reads as the same debug view as the OpenFL one.
const STATIC_COLOR = 0x7fe57f;
const DYNAMIC_COLOR = 0xe5b2b2;
const SLEEPING_COLOR = 0x999999;
const FILL_ALPHA = 0.5;
const LINE_THICKNESS = 1;

// b2FixtureDef's defaults, except for density. Box2D promotes a zero-mass dynamic body to a mass of 1
// with no rotational inertia; Flight derives mass strictly from collider area and density and does
// not promote, so a density of 0 here gives every dynamic body an inverse mass of 0 and nothing falls
// at all. The OpenFL column sets the same density rather than leaning on Box2D's promotion.
//
// Density is per m², so the world scale above changes what a body weighs — the 1 m crate is roughly
// an eleventh of the mass the 3.3 m one had. Nothing here depends on the absolute figure: the drag
// force below is expressed per unit mass, and gravity is an acceleration.
const DENSITY = 1;
const FRICTION = 0.2;
const RESTITUTION = 0;

// Box2D's testbed drag: a 5 Hz spring at 0.7 damping, bounded by a force proportional to the body's
// own mass so heavy things are no harder to move than light ones. Every value carries over unchanged,
// and the OpenFL column passes the same three to its own mouse joint.
const DRAG_FORCE_PER_MASS = 1000;
const DRAG_FREQUENCY_HZ = 5;
const DRAG_DAMPING_RATIO = 0.7;

// A body dragged clear of the stage is put back where it started. The source demo had no way to lose
// one, but dragging does, and nothing else bounds how far a thrown body travels.
const STAGE_WIDTH = 800;
const STAGE_HEIGHT = 600;
const LOST_MARGIN = 200;

interface BodyView {
  body: RigidBody2D;
  node: Shape;
  outline: { kind: 'box'; width: number; height: number } | { kind: 'circle'; radius: number };
  color: number;
  spawnX: number;
  spawnY: number;
}

function isLost(x: number, y: number): boolean {
  return x < -LOST_MARGIN || x > STAGE_WIDTH + LOST_MARGIN || y < -LOST_MARGIN || y > STAGE_HEIGHT + LOST_MARGIN;
}

const root = createDisplayObject();
root.scaleX = scale;
root.scaleY = scale;

// Gravity is positive-y because the scene keeps the source demo's screen-space axis, where y grows
// downward. Flight's own default points the other way, for a y-up world. The magnitude is earth's
// rather than Box2D's customary round 10, so that PIXELS_PER_METRE above is the only thing standing
// between this number and what you see.
const world = createPhysics2DWorld(0, GRAVITY_M_PER_S2);
registerPhysics2DJointSolver(world, Physics2DMouseJointKind, physics2DMouseJointSolver);

const views: BodyView[] = [];

function paint(view: BodyView, color: number): void {
  const node = view.node;
  clearShapeCommands(node);
  appendShapeLineStyle(node, LINE_THICKNESS, color);
  appendShapeBeginFill(node, color, FILL_ALPHA);

  if (view.outline.kind === 'circle') {
    appendShapeCircle(node, 0, 0, view.outline.radius);
    appendShapeEndFill(node);
    // b2DebugDraw lays the body's x axis across the disc, the only way rotation reads on a circle.
    appendShapeMoveTo(node, 0, 0);
    appendShapeLineTo(node, view.outline.radius, 0);
  } else {
    const { width, height } = view.outline;
    appendShapeRectangle(node, -width / 2, -height / 2, width, height);
    appendShapeEndFill(node);
  }

  view.color = color;
}

function bodyColor(body: RigidBody2D): number {
  if (body.type === 'static') return STATIC_COLOR;
  return body.sleeping ? SLEEPING_COLOR : DYNAMIC_COLOR;
}

function addView(body: RigidBody2D, outline: BodyView['outline']): void {
  const view: BodyView = { body, node: createShape(), outline, color: 0, spawnX: body.x, spawnY: body.y };
  addNodeChild(root, view.node);
  paint(view, bodyColor(body));
  place(view);
  views.push(view);
}

function place(view: BodyView): void {
  view.node.x = view.body.x / PHYSICS_SCALE;
  view.node.y = view.body.y / PHYSICS_SCALE;
  view.node.rotation = view.body.angle * RAD_TO_DEG;
  invalidateNodeLocalTransform(view.node);
}

function createBox(x: number, y: number, width: number, height: number, dynamicBody: boolean): RigidBody2D {
  const body = createRigidBody2D(dynamicBody ? 'dynamic' : 'static', x * PHYSICS_SCALE, y * PHYSICS_SCALE);
  body.colliders.push(
    createPhysics2DCollider(
      {
        kind: 'obb',
        x: 0,
        y: 0,
        halfW: (width / 2) * PHYSICS_SCALE,
        halfH: (height / 2) * PHYSICS_SCALE,
        rotation: 0,
      },
      { density: DENSITY, friction: FRICTION, restitution: RESTITUTION },
    ),
  );
  // Mass is derived from the colliders when the body joins the world, so they have to exist first.
  addPhysics2DBody(world, body);
  addView(body, { kind: 'box', width, height });
  return body;
}

function createCircle(x: number, y: number, radius: number, dynamicBody: boolean): RigidBody2D {
  const body = createRigidBody2D(dynamicBody ? 'dynamic' : 'static', x * PHYSICS_SCALE, y * PHYSICS_SCALE);
  body.colliders.push(
    createPhysics2DCollider(
      { kind: 'circle', x: 0, y: 0, radius: radius * PHYSICS_SCALE },
      { density: DENSITY, friction: FRICTION, restitution: RESTITUTION },
    ),
  );
  addPhysics2DBody(world, body);
  addView(body, { kind: 'circle', radius });
  return body;
}

createBox(400, 480, 800, 160, false);
createBox(400, 160, 160, 160, true);
createCircle(160, 160, 80, false);
createCircle(640, 160, 80, true);

const query = createPhysics2DQueryResult();

function bodyAt(worldX: number, worldY: number): RigidBody2D | null {
  queryPhysics2DPoint(world, worldX, worldY, query);

  for (let i = 0; i < query.hitCount; i++) {
    const body = query.hits[i].body;
    if (body.type === 'dynamic') return body;
  }

  return null;
}

let drag: Physics2DMouseJoint | null = null;

function pointerWorld(event: PointerEvent): { x: number; y: number } {
  const bounds = container.getBoundingClientRect();
  return {
    x: ((event.clientX - bounds.left) / scale) * PHYSICS_SCALE,
    y: ((event.clientY - bounds.top) / scale) * PHYSICS_SCALE,
  };
}

container.addEventListener('pointerdown', (event) => {
  const point = pointerWorld(event);
  const body = bodyAt(point.x, point.y);
  if (body === null) return;

  // A sleeping body is skipped by the joint solver, so grabbing one has to wake it first.
  wakePhysics2DBody(body);

  const cos = Math.cos(body.angle);
  const sin = Math.sin(body.angle);
  const offsetX = point.x - body.x;
  const offsetY = point.y - body.y;

  // The anchor is given in the body's own frame, so the grab point has to be rotated out of world
  // space by the body's current angle.
  const joint = createPhysics2DMouseJoint({
    body: body.index,
    targetX: point.x,
    targetY: point.y,
    maxForce: DRAG_FORCE_PER_MASS * body.mass,
    localAnchorX: offsetX * cos + offsetY * sin,
    localAnchorY: -offsetX * sin + offsetY * cos,
    frequencyHz: DRAG_FREQUENCY_HZ,
    dampingRatio: DRAG_DAMPING_RATIO,
  });

  addPhysics2DJoint(world, joint);
  drag = joint;
  container.setPointerCapture(event.pointerId);
});

container.addEventListener('pointermove', (event) => {
  if (drag === null) return;
  const point = pointerWorld(event);
  drag.targetX = point.x;
  drag.targetY = point.y;
});

function endDrag(): void {
  if (drag === null) return;
  removePhysics2DJoint(world, drag);
  drag = null;
}

container.addEventListener('pointerup', endDrag);
container.addEventListener('pointercancel', endDrag);

function resetIfLost(view: BodyView): void {
  if (view.body.type !== 'dynamic') return;
  // The body on the end of the cursor is exempt: it is only out there because it is being held.
  if (drag !== null && drag.bodyB === view.body.index) return;
  if (!isLost(view.body.x / PHYSICS_SCALE, view.body.y / PHYSICS_SCALE)) return;

  view.body.x = view.spawnX;
  view.body.y = view.spawnY;
  view.body.angle = 0;
  view.body.velocityX = 0;
  view.body.velocityY = 0;
  view.body.angularVelocity = 0;
  wakePhysics2DBody(view.body);
}

const app = createApplication();

// The source ran on a stage locked to 30 fps and stepped World.step(1 / 30) once per frame, so its
// step size and its frame rate were the same number by construction. Here the loop runs at whatever
// the display does, so stepping once per frame would tie the simulation's speed to the refresh rate:
// slow motion at 30 fps, double speed at 120.
//
// The accumulator decouples the two. onFixedUpdate fires however many whole 1/30 s steps the elapsed
// time has earned — usually 0 or 1 at 60 fps, more after a stall — so the simulation advances at the
// source's rate in wall-clock terms on any display. The solver still only ever sees the step size it
// was tuned for, which a variable step would not preserve: stiff joints and the resting contacts
// behave differently at 1/144 than at 1/30.
app.onFixedUpdate = createSignal();
connectSignal(app.onFixedUpdate, () => {
  stepPhysics2D(world, PHYSICS_STEP_SECONDS);
});

connectSignal(app.onUpdate, () => {
  for (const view of views) {
    resetIfLost(view);
    place(view);
    const color = bodyColor(view.body);
    if (color !== view.color) paint(view, color);
  }
});
connectSignal(app.onRender, () => render(root));
// maxUpdatesPerFrame is the loop's spiral-of-death guard: if a frame is so late that catching up
// would need more than this many steps, it drops the backlog rather than running ever further
// behind. The loop already clamps a frame to maxDeltaTime (250 ms) first, and 250 ms is 7.5 steps,
// so 8 is the smallest cap that never discards time a clamped frame legitimately earned.
startApplicationLoop(app, { fixedTimeStep: PHYSICS_STEP_MS, maxUpdatesPerFrame: 8 });
