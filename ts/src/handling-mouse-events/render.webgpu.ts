import type { DisplayObject } from '@flighthq/sdk';
import {
  createMatrix,
  createWgpuCanvasElement,
  createWgpuRenderState,
  defaultWgpuShapeCommands,
  defaultWgpuShapeRenderer,
  defaultWgpuSpriteRenderer,
  defaultWgpuTextLabelRenderer,
  prepareScene2DRender,
  registerRenderer,
  registerWgpuImageTextureResolver,
  registerWgpuShapeCommands,
  registerWgpuStandardMaterial,
  renderWgpuBackground,
  renderWgpuScene2D,
  ShapeKind,
  SpriteKind,
  submitWgpuRenderPass,
  TextLabelKind,
} from '@flighthq/sdk';

const pixelRatio = window.devicePixelRatio || 1;
const canvas = createWgpuCanvasElement(800, 600, pixelRatio);
document.getElementById('app')?.remove();
document.body.appendChild(canvas);

export const container = canvas;
export const state = await createWgpuRenderState(canvas, {
  pixelRatio,
  sceneGraphSyncPolicy: 'requiresInvalidation',
  backgroundColor: 0xffffffff,
});
registerRenderer(state, SpriteKind, defaultWgpuSpriteRenderer);
registerRenderer(state, ShapeKind, defaultWgpuShapeRenderer);
registerRenderer(state, TextLabelKind, defaultWgpuTextLabelRenderer);
registerWgpuImageTextureResolver(state);
registerWgpuShapeCommands(state, defaultWgpuShapeCommands);
registerWgpuStandardMaterial(state);
state.renderTransform2D = createMatrix(pixelRatio, 0, 0, pixelRatio, 0, 0);
export const scale = 1;

export function render(root: DisplayObject): void {
  if (!prepareScene2DRender(state, root)) return;
  renderWgpuBackground(state);
  renderWgpuScene2D(state, root);
  submitWgpuRenderPass(state);
}
