import type { DisplayObject } from '@flighthq/sdk';
import {
  createCanvasShapeRasterizer,
  createCanvasTextureResolvers,
  createDomRenderState,
  defaultCanvasShapeCommands,
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
element.style.width = '800px';
element.style.height = '600px';
document.getElementById('app')?.remove();
document.body.appendChild(element);

export const container = element;
export const state = createDomRenderState(element, {
  sceneGraphSyncPolicy: 'requiresInvalidation',
  backgroundColor: 0xffffffff,
});
registerCanvasShapeCommands(state, defaultCanvasShapeCommands);
registerRenderer(state, ShapeKind, defaultDomShapeRenderer);
registerDomShapeRasterizer(state, createCanvasShapeRasterizer(createCanvasTextureResolvers()));
export const scale = 1;

export function render(root: DisplayObject): void {
  if (!prepareScene2DRender(state, root)) return;
  renderDomBackground(state);
  renderDomScene2D(state, root);
}
