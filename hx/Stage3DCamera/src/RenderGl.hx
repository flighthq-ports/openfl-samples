// ts/src/Stage3DCamera: render.webgl.ts.
//
// GL only: Scene3D content, and flight-hx ships scene3dGl and scene3dWgpu but nothing equivalent for
// the DOM or canvas backends. Same boundary ts/ hits.
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
    registerStandardGlTextureResolvers(state);
    registerGlUnlitMaterial(state);

    pipeline = createGlRenderEffectPipeline(state, {depth: 'depth-stencil', format: 'rgba8'});
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
