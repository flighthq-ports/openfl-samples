import type { DisplayObject } from '@flighthq/sdk';
import {
  createMatrix,
  createWgpuCanvasElement,
  createWgpuRenderState,
  defaultWgpuRichTextRenderer,
  defaultWgpuSpriteRenderer,
  prepareScene2DRender,
  registerRenderer,
  registerWgpuImageTextureResolver,
  registerWgpuStandardMaterial,
  renderWgpuBackground,
  renderWgpuScene2D,
  RichTextKind,
  SpriteKind,
  submitWgpuRenderPass,
} from '@flighthq/sdk';

const pixelRatio = window.devicePixelRatio || 1;
const canvas = createWgpuCanvasElement(800, 600, pixelRatio);
document.body.style.margin = '0';
document.getElementById('app')?.remove();
document.body.appendChild(canvas);

export const state = await createWgpuRenderState(canvas, {
  pixelRatio,
  backgroundColor: 0xa0a0a0ff,
  sceneGraphSyncPolicy: 'requiresInvalidation',
});
registerRenderer(state, SpriteKind, defaultWgpuSpriteRenderer);
registerRenderer(state, RichTextKind, defaultWgpuRichTextRenderer);
registerWgpuImageTextureResolver(state);
registerWgpuStandardMaterial(state);
state.renderTransform2D = createMatrix(pixelRatio, 0, 0, pixelRatio, 0, 0);
export const scale = 1;

export function render(root: DisplayObject): void {
  if (!prepareScene2DRender(state, root)) return;
  renderWgpuBackground(state);
  renderWgpuScene2D(state, root);
  submitWgpuRenderPass(state);
}
