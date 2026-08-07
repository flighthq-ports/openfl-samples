// ts/src/hello-triangle: render.webgl.ts.
//
// GL only, and not for want of porting effort: the sample is Scene3D content, and flight-hx ships
// scene3dGl and scene3dWgpu but nothing equivalent for the DOM or canvas backends. That is the same
// boundary ts/ hits, which is why hello-triangle has no render.dom.ts or render.canvas.ts there.
package;

import LimeCanvas.GlCanvas;
import flighthq.sdk.Sdk.*;
import flighthq.types.Camera3D;
import flighthq.types.Node3D;
import flighthq.types.Scene3DLights;
import lime.ui.Window;

class RenderGl {
  public static var state:Dynamic;
  public static var scale:Float = 1;

  static var pipeline:Dynamic;

  public static function init(window:Window):Void {
    scale = window.scale;
    state = createGlRenderState(new GlCanvas(window), {
      backgroundColor: 0xffffffff,
      contextAttributes: {alpha: false, depth: true, preserveDrawingBuffer: false},
      pixelRatio: scale,
    });

    registerGlVertexColorMaterial(state);

    pipeline = createGlRenderEffectPipeline(state, {
      depth: 'depth-stencil',
      format: 'rgba8',
    });
  }

  public static function render(scene:Node3D, camera:Camera3D, lights:Scene3DLights):Void {
    beginGlRenderEffectPipeline(state, pipeline);
    renderGlBackground(state);
    state.gl.depthMask(true);
    state.gl.clearDepth(1);
    state.gl.clear(state.gl.DEPTH_BUFFER_BIT);
    drawGlScene3D(state, scene, camera, lights);
    endGlRenderEffectPipeline(state, pipeline, []);
  }
}
