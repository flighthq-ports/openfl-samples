// ts/src/HandlingMouseEvents: render.webgl.ts.
package;

import LimeCanvas.GlCanvas;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import lime.ui.Window;

class RenderGl {
  public static var state:Dynamic;
  public static var scale:Float = 1;

  public static function init(window:Window):Void {
    scale = window.scale;
    state = createGlRenderState(new GlCanvas(window), {
      pixelRatio: scale,
      sceneGraphSyncPolicy: 'requiresInvalidation',
      backgroundColor: 0xffffffff,
    });
    registerRenderer(state, ShapeKind, defaultGlShapeRenderer);
    registerGlShapeCommands(state, defaultGlShapeCommands);
    registerGlShapeRasterizer(state, createCanvasShapeRasterizer(createCanvasTextureResolvers()));
    registerGlStandardMaterial(state);
    registerRenderer(state, SpriteKind, defaultGlSpriteRenderer);
    registerStandardGlTextureResolvers(state);
    registerRenderer(state, TextLabelKind, defaultGlTextLabelRenderer);
  }

  // ts/ returns void here; this returns whether anything was drawn, so the caller can cancel Lime's
  // present on a skipped frame instead of flipping to a never-drawn back buffer.
  public static function render(root:DisplayObject):Bool {
    if (!prepareScene2DRender(state, root)) return false;
    renderGlBackground(state);
    renderGlScene2D(state, root);
    return true;
  }
}
