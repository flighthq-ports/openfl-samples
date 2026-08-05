import type { DisplayObject } from '@flighthq/sdk';
import {
  createDomRenderState,
  defaultDomRichTextRenderer,
  defaultDomSpriteRenderer,
  prepareScene2DRender,
  registerDomImageTextureResolver,
  registerRenderer,
  renderDomBackground,
  renderDomScene2D,
  RichTextKind,
  SpriteKind,
} from '@flighthq/sdk';

const WIDTH = 800;
const HEIGHT = 600;
const element = document.createElement('div');
element.style.position = 'relative';
element.style.width = `${WIDTH}px`;
element.style.height = `${HEIGHT}px`;
document.body.style.margin = '0';
document.getElementById('app')?.remove();
document.body.appendChild(element);

export const state = createDomRenderState(element, {
  backgroundColor: 0xa0a0a0ff,
  sceneGraphSyncPolicy: 'requiresInvalidation',
});
registerRenderer(state, SpriteKind, defaultDomSpriteRenderer);
registerRenderer(state, RichTextKind, defaultDomRichTextRenderer);
registerDomImageTextureResolver(state);
export const scale = 1;

export function render(root: DisplayObject): void {
  if (!prepareScene2DRender(state, root)) return;
  renderDomBackground(state);
  renderDomScene2D(state, root);
}
