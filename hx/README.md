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
    src/Main.hx                the port of ts/src/drawing-shapes/app.ts
    src/RenderGl.hx            ...of render.webgl.ts
    src/RenderCanvas.hx        ...of render.canvas.ts
    src/RenderDom.hx           ...of render.dom.ts
    src/RenderCairo.hx         Lime's native software context
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
| `render.<backend>.ts` builds the render state over a `<canvas>` | `RenderGl` / `RenderCanvas` / `RenderDom` / `RenderCairo`, one file each |
| `render.ts` re-exports exactly one of them | a `switch (window.context.type)` in `onWindowCreate` binds one `render` function |
| top-level `await loadImageResourceFromUrl(...)` before the scene is built | scene built in `onPreloadComplete` |
| `requestAnimationFrame` loop | Lime's `update(deltaTime)`, stepping the Flight app with `stepApplicationLoop` |
| `render(root)` | Lime's `render(context)` override |
| `attachPointerInput(input, container)` | Lime's `onMouseDown` / `onMouseMove` / `onMouseUp` |
| `attachKeyboardInput(input, window)` | Lime's `onKeyDown` / `onKeyUp` |
| `loadImageResourceFromUrl(...)` | `LimeAssets.image(...)` — see below |
| `loadFontFromUrl(...)` | a bundled TTF registered with the native text backend |

### Picking a backend

One file per render target, mirroring `ts/`'s `render.<backend>.ts`. Each holds only the calls that
sample makes — its own `create*RenderState`, its own registrations, its own `render`. Nothing is
shared or generalised between them, so a file reads as the whole story for that target:

```haxe
class RenderGl {
  public static function init(window:Window):Void {
    state = createGlRenderState(new GlCanvas(window), { ... });
    registerRenderer(state, ShapeKind, defaultGlShapeRenderer);
    registerGlShapeCommands(state, defaultGlShapeCommands);
    ...
  }
}
```

`ts/` picks one at build time by having `render.ts` re-export a single module. Lime picks at runtime
from the context it created, so `Main.hx` switches on `window.context.type` once in `onWindowCreate`
and binds one `render` function for the rest of the run. Bodies that only make sense on one platform
are `#if`-guarded — `RenderDom` and `RenderCanvas` behind `js`, `RenderCairo` behind
`(lime && !js && lime_cairo)` — so a neko build never drags the DOM backend in behind a branch it
cannot take.

**Cairo is its own file**, even though it currently calls the same Flight entry points as
`RenderCanvas`, because cairo-specific entry points are being commissioned upstream. When they land,
only `RenderCairo.hx` changes. Nothing selects it today — the project template has no
`hardware="false"` window — so it compiles but is not exercised.

### Four traps worth knowing

**Build the scene in `onPreloadComplete`, not `onWindowCreate`.** Lime preloads assets
asynchronously and only guarantees them once preloading finishes; `onWindowCreate` runs before that.
Reading an asset there works on neko, where loads are synchronous, and comes back null in a browser —
so the sample runs fine natively and throws on html5. Build the render state in `onWindowCreate`
(it needs the window) and everything that touches an asset in `onPreloadComplete`.

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
| ported; builds and runs clean under `smoke.sh` | `ActuateExample`, `AddingAnimation`, `AddingText`, `AnimatedTilemap`, `Bunnymark`, `CompareBitmapData`, `CreatingAMainLoop`, `DisplayingABitmap`, `DrawingShapes`, `GLSLBitmap`, `HandlingKeyboardEvents`, `HandlingMouseEvents`, `Stage3DCamera`, `Stage3DMipmap`, `TextAlignment`, `TextMetrics`, `TicTacToe`, `UsingBitmapData`, `WorldClock` — subject to the `smoke.sh` run below |
| ported and compiling, but faulting at runtime | `HelloTriangle`, `NyanCat`, `PlayingSound`, `PlayingVideo`, `SimpleBox2D`, `UsingSwfAssets` — see below |
| not yet ported | `PiratePig` — 933 lines across `app.ts`, `game.ts` and `tile.ts`; needs its own pass |

Every project directory exists with its window size, background and assets already wired from the
matching `ts/src/<sample>/render.webgl.ts`, so an outstanding sample is a `Main.hx` away. `build.sh`
prints `-` for a project that has not been ported yet, rather than counting it as a failure.

The four runtime failures are wired against the ordinary Flight APIs — no stubs, no workarounds — so
what they fault on is a straight report of what the generated Haxe port cannot yet do:

| sample | fault | surface |
| --- | --- | --- |
| `SimpleBox2D` | `_Runtime.callProperty: ... has no method isSafeInteger` | `_Runtime` shims the JS `Number` global with only `isNaN`/`parseInt`/`isFinite`/`isInteger`/`parseFloat`; the physics calls `Number.isSafeInteger` |
| `HelloTriangle` | `Invalid call` | Scene3D: `createMeshGeometry` / `createVertexColorMaterial` / `createMesh`, drawn via `createGlRenderEffectPipeline` → `drawGlScene3D` |
| `UsingSwfAssets` | `Layout symbol is missing Background` | `createScene2DSymbolFromSwf` returns a document, but `findNodeByName` finds none of its named children |
| `NyanCat` | `SWF is missing its animated clip` | `createScene2DFromSwf` returns a document whose root has no children |
| `PlayingSound` | `Runtime: cannot construct a JavaScript global that has no portable implementation on this target` | `new AudioContext()`, which `loadAudioResourceFromUrls` / `playAudioResource` need |
| `PlayingVideo` | same class as above | `loadVideoResourceFromUrl` / `createVideoTexture` are backed by an HTML `<video>` element |

`UsingBitmapData` is worth a look too: it runs, but its "drawn" tile still goes through
`document.createElement('canvas')` → `getContext('2d')` → `createBitmapFromCanvas`, because there is
no Flight entry point that composites from a bitmap source. It is wired to the same API `ts/` uses
rather than stubbed, so it will fault on that step outside a browser.

`TextMetrics` carries a placeholder `TextMeasureFunction` — a flat half-em advance — because `ts/`
measures through an offscreen 2D canvas and nothing portable replaces that. The layout runs, but the
metric numbers it reports are not real.

The SWF pair corroborate each other: two different SWF entry points, two different files, both decode
without raising and both yield an empty scene, so SWF parsing looks incomplete rather than misused.

Note on stale builds: changing an `<assets>` entry does not always cause Lime to re-embed on an
incremental build, and a sample then fails at runtime against the old embedded set in a way that
looks like a code bug. If a sample faults right after an asset change, `rm -rf <project>/bin` and
rebuild before believing the error.

Ones to expect trouble on, and why: `PlayingVideo` and `UsingBitmapData` lean on browser video and
Canvas-2D painting (flight-hx's convention is a minimal in-file stub that keeps the SDK call sites
identical); `Bunnymark` uses `stats.js`; `GLSLBitmap` is a custom fragment shader and so has no
cairo/software path; `HelloTriangle` and the two `Stage3D*` samples need the `scene3dGl` pipeline
inlined the way flight-hx's `scene3d` example does.

**Debug builds.** `#if debug` is the direct analogue of the `import.meta.env.DEV` guard the
TypeScript tree uses in `ts/dev/explain.ts`, so both trees stay diagnosable the same way.
