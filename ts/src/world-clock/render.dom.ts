import type { DisplayObject } from '@flighthq/sdk';
import {
  createCanvasShapeRasterizer,
  createCanvasTextureResolvers,
  createDomRenderState,
  defaultCanvasBeginFill,
  defaultCanvasDrawCircle,
  defaultCanvasLineStyle,
  defaultCanvasLineTo,
  defaultCanvasMoveTo,
  defaultDomShapeRenderer,
  defaultDomTextLabelRenderer,
  prepareScene2DRender,
  registerCanvasShapeCommands,
  registerDomShapeRasterizer,
  registerRenderer,
  renderDomBackground,
  renderDomScene2D,
  ShapeKind,
  TextLabelKind,
} from '@flighthq/sdk';

const element = document.createElement('div');
element.style.position = 'relative';
element.style.width = '370px';
element.style.height = '140px';
document.getElementById('app')?.remove();
document.body.appendChild(element);

export const container = element;
export const state = createDomRenderState(element, {
  sceneGraphSyncPolicy: 'requiresInvalidation',
  backgroundColor: 0xffffffff,
});
registerRenderer(state, ShapeKind, defaultDomShapeRenderer);
registerRenderer(state, TextLabelKind, defaultDomTextLabelRenderer);
registerCanvasShapeCommands(state, [
  defaultCanvasBeginFill,
  defaultCanvasDrawCircle,
  defaultCanvasLineStyle,
  defaultCanvasLineTo,
  defaultCanvasMoveTo,
]);
registerDomShapeRasterizer(state, createCanvasShapeRasterizer(createCanvasTextureResolvers()));
export const scale = 1;

export function setSize(width: number, height: number): void {
  element.style.width = `${width}px`;
  element.style.height = `${height}px`;
}

export function render(root: DisplayObject): void {
  if (!prepareScene2DRender(state, root)) return;
  renderDomBackground(state);
  renderDomScene2D(state, root);
}
