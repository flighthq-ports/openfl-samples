// Haxe/Lime port of ts/src/hello-triangle/app.ts.
//
// Scene3D content, so this one is GL only — see RenderGl.hx. ts/ spins the triangle off
// performance.now(); Lime's update(deltaTime) accumulates the same elapsed milliseconds.
package;

import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.Mesh;
import flighthq.types.MeshGeometry.VertexAttributeLayout;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  static final LAYOUT:VertexAttributeLayout = {
    attributes: [
      {byteOffset: 0, format: 'float32x3', semantic: 'position'},
      {byteOffset: 12, format: 'float32x4', semantic: 'color0'},
    ],
    stride: 28,
  };

  var ready = false;
  var elapsed:Float = 0;

  var scene:Dynamic;
  var mesh:Mesh;
  var camera:Dynamic;
  var lights:Dynamic;
  var zAxis:Dynamic;

  public function new() {
    super();
  }

  override public function onWindowCreate():Void {
    App.setAppBackend(LimeApp.createLimeAppBackend(this));
    switch (window.context.type) {
      case OPENGL, OPENGLES, WEBGL:
        RenderGl.init(window);
      default:
        throw 'hello-triangle is Scene3D content and needs an OpenGL/WebGL context; got ' + window.context.type;
    }

    final geometry = createMeshGeometry({
      indices: new flighthq._internal._UInt16Array(([0, 1, 2] : Array<Int>)),
      layout: LAYOUT,
      vertices: new flighthq._internal._Float32Array(([
        -0.3, -0.3, 0, 1, 0, 0, 1,
        -0.3, 0.3, 0, 0, 1, 0, 1,
         0.3, 0.3, 0, 0, 0, 1, 1,
      ] : Array<Float>)),
    });

    scene = createScene3D();
    final material = createVertexColorMaterial({tint: 0xffffffff});
    material.doubleSided = true;
    mesh = createMesh(geometry, [material]);
    addNodeChild(scene.root, mesh);

    camera = createCamera3D({
      far: 10,
      near: 0.1,
      projection: createOrthographicProjection({halfHeight: 1, halfWidth: 1}),
    });
    setCamera3DViewMatrix4FromLookAt(camera, createVector3(0, 0, 1), createVector3(0, 0, 0), createVector3(0, 1, 0));

    lights = createScene3DLights();
    zAxis = createVector3(0, 0, 1);

    ready = true;
  }

  override public function update(deltaTime:Int):Void {
    if (!ready) return;
    elapsed += deltaTime;
    setQuaternionFromAxisAngle(mesh.rotation, zAxis, (elapsed / 40) * (Math.PI / 180));
    invalidateNodeLocalTransform(mesh);
  }

  override public function render(context:RenderContext):Void {
    if (!ready) return;
    RenderGl.render(scene.root, camera, lights);
  }
}
