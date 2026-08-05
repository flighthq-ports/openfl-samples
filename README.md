# OpenFL Samples (Flight SDK)

26 samples from [openfl/openfl-samples](https://github.com/openfl/openfl-samples), ported to
[Flight](https://github.com/flighthq/flight) — built against
[`@flighthq/sdk`](https://www.npmjs.com/package/@flighthq/sdk).

## Build and run

```bash
cd ts
npm install
npm run dev
```

Samples live in `ts/src/<name>/`. Each is self-contained; `npm run eject <name>` copies one out as
a standalone project.

| Command | |
| --- | --- |
| `npm run dev` | dev server and sample index |
| `npm run build` | build every sample (WebGL) |
| `npm run build:renderers` | also build the Canvas, WebGPU and DOM variants |
| `npm run dist` | the full published output — thumbs, sizes, gallery, all builds |
| `npm run eject <name>` | copy one sample out |
| `npm run thumbs` | capture gallery thumbnails (needs `npx playwright install chromium`) |
| `npm run sizes` | write `SIZES.md` and `src/sizes.json` |
| `npm run lint:assets` | check asset references |

Thumbnails and sizes are optional. They are gitignored and the gallery picks them up at view time,
so a plain clone renders fine without them and a published build is richer for having them.

## Backends

A sample hard-codes its renderer — `render.ts` re-exports exactly one `render.<backend>.ts` — and
registers only the pieces that backend needs. That explicit opt-in is what lets the bundler drop
everything else, and it is why a sample is measured in kilobytes rather than hundreds of them.

`npm run dist` publishes the WebGL build at `/<sample>/` and each alternate at
`/<sample>/<backend>/` — the sample owns its variants, so trimming the URL lands on the sample
rather than a dead path. The DOM build is the interesting one to poke at: open devtools and the
display list is sitting there as real elements rather than a canvas.

Variants only exist once built. In dev the server runs one backend at a time, so use
`RENDERER=canvas npm run dev`; visiting a variant URL there explains as much rather than silently
serving the gallery.

Coverage is uneven, and every gap is a backend boundary rather than an unfinished port. Scene3D
currently has only a WebGL renderer, so `hello-triangle` and the `stage3d-*` samples are WebGL only,
and `glsl-bitmap` is WebGL only because its subject is a custom GLSL shader.

| backend | samples | what it cannot reach |
| --- | --- | --- |
| WebGL | 26 | — |
| Canvas | 22 | `glsl-bitmap`, `hello-triangle`, and the two `stage3d-*` samples |
| DOM | 21 | the four Canvas cannot reach, plus `bunnymark` — there is no DOM `QuadBatch` renderer |
| WebGPU | 22 | `glsl-bitmap`, `hello-triangle`, and the two `stage3d-*` samples |

DOM's boundary is the sharpest of the four, because it is drawn by what `scene2d-dom` provides
rather than by porting effort. It renders `Shape`, `Sprite`, `TextLabel`, `RichText`, `MorphShape`
and `Scale9Shape`; it has no `QuadBatch`, `Tilemap`, `BitmapText` or `ParticleEmitter2D` renderer,
and there is no `scene3d-dom` at all. It is also not purely a subset — `HtmlView` and `NativeText`
render *only* on DOM.

One wiring detail is easy to get wrong and fails silently. `defaultDomShapeRenderer` draws no paths
itself: it allocates a `<canvas>` per `Shape` and hands the commands to a registered rasterizer. A
DOM state that registers shape *commands* but never calls `registerDomShapeRasterizer` drops every
shape without an error. Every DOM sample here that draws a `Shape` registers one.
