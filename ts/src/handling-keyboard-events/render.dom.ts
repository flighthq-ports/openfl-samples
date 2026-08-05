import type { DisplayObject } from '@flighthq/sdk';
import {
  createCanvasShapeRasterizer,
  createCanvasTextureResolvers,
  createDomRenderState,
  defaultCanvasBeginFill,
  defaultCanvasDrawCircle,
  defaultCanvasDrawEllipse,
  defaultCanvasDrawRectangle,
  defaultCanvasDrawRoundRectangle,
  defaultCanvasLineStyle,
  defaultCanvasLineTo,
  defaultCanvasMoveTo,
  defaultDomShapeRenderer,
  defaultDomSpriteRenderer,
  defaultDomTextLabelRenderer,
  prepareScene2DRender,
  registerCanvasShapeCommands,
  registerDomImageTextureResolver,
  registerDomShapeRasterizer,
  registerRenderer,
  renderDomBackground,
  renderDomScene2D,
  ShapeKind,
  SpriteKind,
  TextLabelKind,
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
registerRenderer(state, SpriteKind, defaultDomSpriteRenderer);
registerDomImageTextureResolver(state);
registerRenderer(state, ShapeKind, defaultDomShapeRenderer);
registerRenderer(state, TextLabelKind, defaultDomTextLabelRenderer);
registerCanvasShapeCommands(state, [
  defaultCanvasBeginFill,
  defaultCanvasDrawCircle,
  defaultCanvasDrawEllipse,
  defaultCanvasDrawRectangle,
  defaultCanvasDrawRoundRectangle,
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
