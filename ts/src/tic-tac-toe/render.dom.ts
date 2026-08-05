import type { DisplayObject } from '@flighthq/sdk';
import {
  createCanvasShapeRasterizer,
  createCanvasTextureResolvers,
  createDomRenderState,
  defaultCanvasDrawCircle,
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

const element = document.createElement('div');
element.style.position = 'relative';
element.style.width = '170px';
element.style.height = '170px';
document.getElementById('app')?.remove();
document.body.appendChild(element);

export const container = element;
export const state = createDomRenderState(element, {
  sceneGraphSyncPolicy: 'requiresInvalidation',
  backgroundColor: 0xffffffff,
});
registerRenderer(state, ShapeKind, defaultDomShapeRenderer);
registerCanvasShapeCommands(state, [
  defaultCanvasDrawCircle,
  defaultCanvasLineStyle,
  defaultCanvasLineTo,
  defaultCanvasMoveTo,
]);
registerDomShapeRasterizer(state, createCanvasShapeRasterizer(createCanvasTextureResolvers()));
export const scale = 1;

export function render(root: DisplayObject): void {
  if (!prepareScene2DRender(state, root)) return;
  renderDomBackground(state);
  renderDomScene2D(state, root);
}
