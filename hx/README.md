# Haxe / Lime port

The same samples as `ts/`, built against
[flight-hx](https://github.com/flighthq/flight-hx) — the Flight SDK mechanically ported to Haxe —
running on Lime.

The point is not a second copy of the TypeScript samples. `ts/` is the web story; this tree is the
same sample compiling outside the browser. The targets exercised here are `neko` and `html5`; the
native targets (`linux`/`windows`/`mac`/`ios`/`android`) additionally need Lime's native library for
that platform and are untested.

## Layout

```
hx/
  build.sh                     compile every project, print a pass/fail table
  smoke.sh                     run each built neko app briefly, fail on an uncaught exception
  DrawingShapes/
    project.xml                standalone Lime app, own <assets> lines
    src/Main.hx                the port of ts/src/drawing-shapes
    src/Renderer.hx            picks the Flight backend from the Lime context type
    src/LimeCanvas.hx          Lime->Flight surface adapters and asset loader
```

One Lime project per sample, mirroring `ts/src/<sample>/`. Directory names are PascalCase because
they are also the app names — hand-mapped rather than derived, which is why `glsl-bitmap` is
`GLSLBitmap` and not `GlslBitmap`.

Assets come from the shared `../assets/` corpus, named per project in `<assets>` tags under the same
relative ids `ts/` uses, so the Flight call sites read identically in both trees.

## Prerequisites

```sh
sudo apt install haxe neko          # or any Haxe 4.3+ toolchain
sudo apt install xvfb               # only for smoke.sh, to run a headless window
haxelib setup                       # once, to pick a library directory
haxelib install lime                # the `lime` command and its ndll
git clone https://github.com/flighthq/flight-hx
haxelib dev flight path/to/flight-hx
```

Each `project.xml` pulls the SDK in as `<haxelib name="flight" />`, so the `haxelib dev` link above
is what points the build at your checkout.

## Building

```sh
./build.sh                          # every project, every target
./build.sh html5-dom                # one target
./build.sh neko DrawingShapes       # one target, named projects
```

| target | Lime context | Flight backend | `ts/` counterpart |
| --- | --- | --- | --- |
| `neko` | `OPENGL` | `scene2dGl` | `render.webgl.ts` |
| `html5` | `WEBGL` | `scene2dGl` | `render.webgl.ts` |
| `html5-canvas` | `CANVAS` | `scene2dCanvas` | `render.canvas.ts` |
| `html5-dom` | `DOM` | `scene2dDom` | `render.dom.ts` |

Output lands in `<project>/bin/<target>/bin/` and is gitignored; per-project compiler logs go to
`<project>/bin/build-<target>.log`.

Compiling is weak evidence on its own — the asset trap below builds clean and dies at startup — so
after a neko build, run the apps too:

```sh
./build.sh neko && ./smoke.sh
```

## How a port maps onto Lime

The whole SDK is exposed as `flighthq.sdk.Sdk` statics whose names match the TypeScript exports, so
`import flighthq.sdk.Sdk.*;` makes the body of a sample a near-direct transcription. What differs is
the host glue, and it differs the same way every time:

| `ts/` | here |
| --- | --- |
| `render.<backend>.ts` builds the render state over a `<canvas>` | `new Renderer(window, background)` in `onWindowCreate` |
| that module registers the kinds the sample draws | `renderer.useShapes()` / `useSprites()` / `useTextLabels()` / `useRichText()` |
| `requestAnimationFrame` loop | Lime's `update(deltaTime)`, stepping the Flight app with `stepApplicationLoop` |
| `render(root)` | Lime's `render(context)` override |
| `attachPointerInput(input, container)` | Lime's `onMouseDown` / `onMouseMove` / `onMouseUp` |
| `attachKeyboardInput(input, window)` | Lime's `onKeyDown` / `onKeyUp` |
| `loadImageResourceFromUrl(...)` | `LimeAssets.image(...)` — see below |
| `loadFontFromUrl(...)` | a bundled TTF registered with the native text backend |

### Picking a backend

`Renderer` switches on `window.context.type`, which is Lime's own convention, and builds the matching
Flight render state — `createDomRenderState`, `createCanvasRenderState` or `createGlRenderState`.
Lime decides the context from the build: `-Ddom` and `-Dcanvas` on html5, otherwise WebGL; on neko,
OpenGL, or Cairo when the window asks for `hardware="false"`.

A sample never names a backend. It says which *kinds* it draws:

```haxe
renderer = new Renderer(window, 0xffffffff);
renderer.useShapes();
renderer.useTextLabels();
```

Each `use*` expands to that backend's registration set — including the parts that are easy to forget,
like the shape rasterizer the DOM and GL backends both need for vector fills but the Canvas backend
does not. Registering only the kinds a sample draws is deliberate: it is the same explicit opt-in
`ts/` relies on to let the bundler drop everything else.

**Cairo is its own branch**, even though it currently drives the same Flight canvas entry points as
`CANVAS`, because cairo-specific entry points are being commissioned upstream. When they land, only
the `CAIRO` case and the draw switch change. Nothing selects it today — the template has no
`hardware="false"` window — so the branch compiles but is not exercised.

### Three traps worth knowing

**Assets must be `embed="true"`.** Without it the project builds clean and then dies on the first
frame with `[lime.utils.Assets] ERROR: There is no asset library named "default", or it is not yet
preloaded` — the non-embedded default library is never preloaded on these targets, so every asset id
misses. Embedding compiles the bytes into the binary and sidesteps the preload entirely. `smoke.sh`
exists to catch exactly this, because `build.sh` cannot.

**`loadImageResourceFromUrl` and `loadFontFromUrl` are browser-only.** The generated port drives
`new Image()`, `img.decode()` and the FontFace API through the JS global object, none of which exist
on neko. Lime already decodes PNG and TTF on every target, so assets are declared in `project.xml`,
read through `lime.utils.Assets`, and handed to Flight as raw RGBA bytes via `createBitmap` +
`createImageResourceFromBitmap` — the same path flight-hx's own examples use. That is what
`LimeAssets` in `src/LimeCanvas.hx` wraps; every Flight call site downstream is unchanged.

**`GlCanvas.width` / `.height` must be plain fields, not properties.** Flight's GL renderer reads
them reflectively to build the viewport and the pixel→clip projection. A Haxe `(get, never)`
property compiles to a getter with no reflectable field behind it, so the read yields null, the
viewport collapses to 0×0 and the projection goes NaN — every draw is silently discarded while the
background clear still paints, which looks like a working app that renders nothing.

## Coverage

`ts/` leads; a sample exists in this tree or it does not.

| state | samples |
| --- | --- |
| ported; builds on all four targets and runs clean under `smoke.sh` | `AddingText`, `CreatingAMainLoop`, `DisplayingABitmap`, `DrawingShapes`, `TicTacToe` |
| scaffolded (`project.xml` + `LimeCanvas.hx`), `Main.hx` not yet written | the other 21 |

Every project directory exists with its window size, background and assets already wired from the
matching `ts/src/<sample>/render.webgl.ts`, so an outstanding sample is a `Main.hx` away. `build.sh`
prints `-` for a project that has not been ported yet, rather than counting it as a failure.

Ones to expect trouble on, and why: `PlayingVideo` and `UsingBitmapData` lean on browser video and
Canvas-2D painting (flight-hx's convention is a minimal in-file stub that keeps the SDK call sites
identical); `Bunnymark` uses `stats.js`; `GLSLBitmap` is a custom fragment shader and so has no
cairo/software path; `HelloTriangle` and the two `Stage3D*` samples need the `scene3dGl` pipeline
inlined the way flight-hx's `scene3d` example does.

**Debug builds.** `#if debug` is the direct analogue of the `import.meta.env.DEV` guard the
TypeScript tree uses in `ts/dev/explain.ts`, so both trees stay diagnosable the same way.
