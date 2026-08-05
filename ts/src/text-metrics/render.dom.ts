import type { DisplayObject } from '@flighthq/sdk';
import {
  createCanvasShapeRasterizer,
  createCanvasTextureResolvers,
  createDomRenderState,
  defaultCanvasBeginFill,
  defaultCanvasDrawRectangle,
  defaultDomRichTextRenderer,
  defaultDomShapeRenderer,
  prepareScene2DRender,
  registerCanvasShapeCommands,
  registerDomShapeRasterizer,
  registerRenderer,
  renderDomBackground,
  renderDomScene2D,
  RichTextKind,
  ShapeKind,
} from '@flighthq/sdk';

const element = document.createElement('div');
element.style.position = 'relative';
element.style.width = '800px';
element.style.height = '600px';
document.body.style.margin = '0';
document.getElementById('app')?.remove();
document.body.appendChild(element);

export const container = element;
export const state = createDomRenderState(element, {
  sceneGraphSyncPolicy: 'requiresInvalidation',
  backgroundColor: 0xa0a0a0ff,
});
registerRenderer(state, RichTextKind, defaultDomRichTextRenderer);
registerRenderer(state, ShapeKind, defaultDomShapeRenderer);
registerCanvasShapeCommands(state, [defaultCanvasBeginFill, defaultCanvasDrawRectangle]);
// The DOM shape renderer owns no path drawing of its own: it allocates a <canvas> per Shape and
// hands the commands to the registered rasterizer. Without this, every Shape silently draws nothing.
registerDomShapeRasterizer(state, createCanvasShapeRasterizer(createCanvasTextureResolvers()));
export const scale = 1;

export function render(root: DisplayObject): void {
  if (!prepareScene2DRender(state, root)) return;
  renderDomBackground(state);
  renderDomScene2D(state, root);
}

export function setSize(w: number, h: number): void {
  element.style.width = `${w}px`;
  element.style.height = `${h}px`;
}
