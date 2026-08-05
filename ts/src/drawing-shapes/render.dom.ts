import type { DisplayObject } from '@flighthq/sdk';
import {
  createCanvasShapeRasterizer,
  createCanvasTextureResolvers,
  createDomRenderState,
  defaultCanvasBeginFill,
  defaultCanvasCurveTo,
  defaultCanvasDrawCircle,
  defaultCanvasDrawEllipse,
  defaultCanvasDrawRectangle,
  defaultCanvasDrawRoundRectangle,
  defaultCanvasLineStyle,
  defaultCanvasLineTo,
  defaultCanvasMoveTo,
  defaultDomShapeRenderer,
  prepareScene2DRender,
  registerCanvasShapeCommands,
  registerDomShapeRasterizer,
  registerRenderer,
  renderDomBackground,
  renderDomScene2D,
  ShapeKind,
} from '@flighthq/sdk';

const container = document.createElement('div');
container.style.position = 'relative';
container.style.width = '650px';
container.style.height = '600px';
document.getElementById('app')?.remove();
document.body.appendChild(container);

export const state = createDomRenderState(container, {
  sceneGraphSyncPolicy: 'requiresInvalidation',
  backgroundColor: 0xffffffff,
});
registerRenderer(state, ShapeKind, defaultDomShapeRenderer);
registerCanvasShapeCommands(state, [
  defaultCanvasBeginFill,
  defaultCanvasCurveTo,
  defaultCanvasDrawCircle,
  defaultCanvasDrawEllipse,
  defaultCanvasDrawRectangle,
  defaultCanvasDrawRoundRectangle,
  defaultCanvasLineStyle,
  defaultCanvasLineTo,
  defaultCanvasMoveTo,
]);
// The DOM shape renderer owns no path drawing of its own: it allocates a <canvas> per Shape and
// hands the commands to the registered rasterizer. Without this, every Shape silently draws nothing.
registerDomShapeRasterizer(state, createCanvasShapeRasterizer(createCanvasTextureResolvers()));
export const scale = 1;

export function render(root: DisplayObject): void {
  if (!prepareScene2DRender(state, root)) return;
  renderDomBackground(state);
  renderDomScene2D(state, root);
}
