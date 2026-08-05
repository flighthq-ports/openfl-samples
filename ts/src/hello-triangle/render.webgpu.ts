import type { Camera3D, Node3D, Scene3DLights } from '@flighthq/sdk';
import {
  createWgpuCanvasElement,
  createWgpuRenderState,
  drawWgpuScene3D,
  registerWgpuVertexColorMaterial,
  renderWgpuBackground,
  submitWgpuRenderPass,
} from '@flighthq/sdk';

const width = 800;
const height = 600;
const pixelRatio = window.devicePixelRatio || 1;
const canvas = createWgpuCanvasElement(width, height, pixelRatio);

const mount = document.getElementById('app');
if (mount) {
  mount.replaceWith(canvas);
} else {
  document.body.appendChild(canvas);
}

document.body.style.margin = '0';

const state = await createWgpuRenderState(canvas, {
  backgroundColor: 0xffffffff,
  pixelRatio,
});

registerWgpuVertexColorMaterial(state);

export function render(scene: Readonly<Node3D>, camera: Readonly<Camera3D>, lights: Readonly<Scene3DLights>): void {
  renderWgpuBackground(state);
  drawWgpuScene3D(state, scene, camera, lights);
  submitWgpuRenderPass(state);
}
