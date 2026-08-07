// ts/src/glsl-bitmap: render.webgl.ts.
//
// GL only, and for the reason the sample exists: its subject is a custom GLSL fragment shader, which
// has no canvas or DOM equivalent. ts/ has no render.canvas.ts or render.dom.ts here either.
package;

import LimeCanvas.GlCanvas;
import flighthq.effectsGl.GlCustomShaderEffect.applyCustomShaderEffectToGl;
import flighthq.effectsGl.GlCustomShaderEffect.registerGlCustomShaderSource;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import lime.ui.Window;

class RenderGl {
  public static var state:Dynamic;
  public static var scale:Float = 1;

  static var pipeline:Dynamic;

  public static function init(window:Window):Void {
    scale = window.scale;
    state = createGlRenderState(new GlCanvas(window), {
      pixelRatio: scale,
      sceneGraphSyncPolicy: 'requiresInvalidation',
      backgroundColor: 0xffffffff,
    });
    registerStandardGlTextureResolvers(state);
    registerRenderer(state, SpriteKind, defaultGlSpriteRenderer);
    registerGlStandardMaterial(state);
    registerGlRenderEffect(state, 'CustomShaderEffect', function(context:Dynamic, effect:Dynamic) {
      applyCustomShaderEffectToGl(context.state, context.source, context.dest, effect);
    });

    pipeline = createGlRenderEffectPipeline(state);
  }

  public static function registerCustomShader(shaderKey:String, fragmentSource:String):Void {
    registerGlCustomShaderSource(state, shaderKey, fragmentSource);
  }

  public static function render(root:DisplayObject, effects:Array<Dynamic>):Bool {
    if (!prepareScene2DRender(state, root)) return false;
    beginGlRenderEffectPipeline(state, pipeline);
    renderGlBackground(state);
    renderGlScene2D(state, root);
    endGlRenderEffectPipeline(state, pipeline, effects);
    return true;
  }
}
