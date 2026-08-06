import {
  addNodeChild,
  attachKeyboardInput,
  connectSignal,
  createApplication,
  createDisplayObject,
  createInputManager,
  createSprite,
  createTexture,
  invalidateNodeLocalTransform,
  loadImageResourceFromUrl,
  startApplicationLoop,
} from '@flighthq/sdk';

import { render, scale } from './render';

const SPEED_PX_PER_SECOND = 5 * 60;

const image = await loadImageResourceFromUrl('images/openfl_icon.png');
const root = createDisplayObject();
root.scaleX = scale;
root.scaleY = scale;

const logo = createSprite();
logo.data.texture = createTexture({ source: image });
logo.x = 100;
logo.y = 100;
addNodeChild(root, logo);

const held = new Set<string>();
const input = createInputManager();
attachKeyboardInput(input, window);
connectSignal(input.onKeyDown, (data) => held.add(data.key));
connectSignal(input.onKeyUp, (data) => held.delete(data.key));

const app = createApplication();
connectSignal(app.onUpdate, (delta) => {
  // The source moved the logo 5 px per frame on a 60 fps stage. Held here as a rate rather than a
  // per-frame constant, so the logo covers the same ground per second whatever the display does —
  // per-frame it would crawl on a 30 Hz panel and bolt on a 120 Hz one.
  const step = SPEED_PX_PER_SECOND * (delta / 1000);
  if (held.has('ArrowDown')) logo.y += step;
  if (held.has('ArrowLeft')) logo.x -= step;
  if (held.has('ArrowRight')) logo.x += step;
  if (held.has('ArrowUp')) logo.y -= step;
  invalidateNodeLocalTransform(logo);
});
connectSignal(app.onRender, () => render(root));
startApplicationLoop(app);
