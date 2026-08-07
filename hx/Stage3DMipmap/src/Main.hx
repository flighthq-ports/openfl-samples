// Haxe/Lime port of ts/src/Stage3DMipmap/app.ts.
//
// GL only — see RenderGl.hx. Arrow keys move the camera; ts/ binds them to window keydown/keyup,
// Lime delivers the same as onKeyDown/onKeyUp overrides.
package;

import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.Mesh;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;

class Main extends Application {
  static inline final DAMPING = 1.09;
  static inline final LINEAR_ACCELERATION = 0.0005;
  static inline final MAX_FORWARD_VELOCITY = 0.05;
  static inline final MAX_ROTATION_VELOCITY = 0.5;
  static inline final ROTATION_ACCELERATION = 0.01;

  var ready = false;
  var elapsed:Float = 0;

  var scene:Dynamic;
  var mesh:Mesh;
  var camera:Dynamic;
  var lights:Dynamic;
  var cameraEye:Dynamic;
  var cameraTarget:Dynamic;
  var up:Dynamic;

  var cameraLinearAcceleration:Float = 0;
  var cameraLinearVelocity:Float = 0;
  var cameraRotationAcceleration:Float = 0;
  var cameraRotationVelocity:Float = 0;
  var cameraYaw:Float = 0;

  public function new() {
    super();
  }

  override public function onWindowCreate():Void {
    App.setAppBackend(LimeApp.createLimeAppBackend(this));
    switch (window.context.type) {
      case OPENGL, OPENGLES, WEBGL:
        RenderGl.init(window);
      default:
        throw 'Stage3DMipmap is Scene3D content and needs an OpenGL/WebGL context; got ' + window.context.type;
    }
  }

  override public function onPreloadComplete():Void {
    final image = LimeAssets.image('images/checkers.png');
    final texture = createTexture(cast {dimension: '2d', source: image, sampler: createAnisotropicSampler(16)});

    scene = createScene3D();
    final material = createUnlitMaterial({baseColor: 0xffffffff, baseColorMap: texture});
    material.doubleSided = true;
    mesh = createMesh(createQuadMeshGeometry(0.6, 0.6), [material]);
    mesh.position.z = 1;
    addNodeChild(scene.root, mesh);

    camera = createCamera3D({
      far: 1000,
      near: 0.1,
      projection: createPerspectiveProjection({aspect: 4 / 3, fovY: (45 * Math.PI) / 180}),
    });

    lights = createScene3DLights();
    cameraEye = createVector3(0, 0, 2);
    cameraTarget = createVector3(0, 0, 1);
    up = createVector3(0, 1, 0);

    ready = true;
  }

  static function updateVelocity(velocity:Float, acceleration:Float, max:Float):Float {
    if (acceleration != 0) return Math.max(-max, Math.min(max, velocity + acceleration));
    return velocity / DAMPING;
  }

  override public function onKeyDown(keyCode:KeyCode, modifier:KeyModifier):Void {
    if (keyCode == KeyCode.LEFT) cameraRotationAcceleration = -ROTATION_ACCELERATION;
    else if (keyCode == KeyCode.RIGHT) cameraRotationAcceleration = ROTATION_ACCELERATION;
    else if (keyCode == KeyCode.UP) cameraLinearAcceleration = LINEAR_ACCELERATION;
    else if (keyCode == KeyCode.DOWN) cameraLinearAcceleration = -LINEAR_ACCELERATION;
  }

  override public function onKeyUp(keyCode:KeyCode, modifier:KeyModifier):Void {
    if (keyCode == KeyCode.LEFT || keyCode == KeyCode.RIGHT) cameraRotationAcceleration = 0;
    else if (keyCode == KeyCode.UP || keyCode == KeyCode.DOWN) cameraLinearAcceleration = 0;
  }

  override public function update(deltaTime:Int):Void {
    if (!ready) return;
    elapsed += deltaTime;

    cameraLinearVelocity = updateVelocity(cameraLinearVelocity, cameraLinearAcceleration, MAX_FORWARD_VELOCITY);
    cameraRotationVelocity = updateVelocity(cameraRotationVelocity, cameraRotationAcceleration, MAX_ROTATION_VELOCITY);
    cameraYaw += cameraRotationVelocity;
    final yawRad = (cameraYaw * Math.PI) / 180;
    cameraEye.x += Math.sin(yawRad) * cameraLinearVelocity;
    cameraEye.z -= Math.cos(yawRad) * cameraLinearVelocity;
    cameraTarget.x = cameraEye.x + Math.sin(yawRad);
    cameraTarget.y = 0;
    cameraTarget.z = cameraEye.z - Math.cos(yawRad);
    setCamera3DViewMatrix4FromLookAt(camera, cameraEye, cameraTarget, up);

    final deg = Math.PI / 180;
    setQuaternionFromEuler(mesh.rotation, -(elapsed / 10) * deg, -(elapsed / 30) * deg, 0, 'XYZ');
    invalidateNodeLocalTransform(mesh);
  }

  override public function render(context:RenderContext):Void {
    if (!ready) return;
    RenderGl.render(scene.root, camera, lights);
  }
}
