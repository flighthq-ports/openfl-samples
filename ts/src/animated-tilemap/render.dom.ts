import type { Sprite } from '@flighthq/sdk';
import {
  createDomRenderState,
  defaultDomSpriteRenderer,
  prepareScene2DRender,
  registerDomImageTextureResolver,
  registerRenderer,
  renderDomBackground,
  renderDomScene2D,
  SpriteKind,
} from '@flighthq/sdk';

const element = document.createElement('div');
element.style.position = 'relative';
element.style.width = '800px';
element.style.height = '600px';
document.getElementById('app')?.remove();
document.body.appendChild(element);

export const state = createDomRenderState(element, {
  sceneGraphSyncPolicy: 'requiresInvalidation',
  backgroundColor: 0xffffffff,
  imageSmoothingEnabled: false,
});
registerRenderer(state, SpriteKind, defaultDomSpriteRenderer);
registerDomImageTextureResolver(state);
export const scale = 1;

export function render(root: Sprite): void {
  if (!prepareScene2DRender(state, root)) return;
  renderDomBackground(state);
  renderDomScene2D(state, root);
}
