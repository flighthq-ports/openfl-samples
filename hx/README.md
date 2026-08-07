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
  src/DrawingShapes/
    project.xml                standalone Lime app, own <assets> lines
    Source/Main.hx             the port of ts/src/drawing-shapes
    Source/LimeCanvas.hx       Lime->Flight adapters and asset loader
```

One Lime project per sample, mirroring `ts/src/<sample>/`. Directory names are PascalCase because
they are also the app names — hand-mapped rather than derived, which is why `glsl-bitmap` is
`GLSLBitmap` and not `GlslBitmap`.

Assets come from the shared `../assets/` corpus, named per project in `<assets>` tags under the same
relative ids `ts/` uses, so the Flight call sites read identically in both trees.

## Prerequisites

```sh
sudo apt install haxe neko          # or any Haxe 4.3+ toolchain
haxelib setup                       # once, to pick a library directory
haxelib install lime                # the `lime` command and its ndll
git clone https://github.com/flighthq/flight-hx
haxelib dev flight path/to/flight-hx
```

## Building

```sh
./build.sh                          # every project, neko and html5
./build.sh html5                    # one target
./build.sh neko DrawingShapes       # one target, named projects
```

Output lands in `src/<project>/bin/<target>/bin/` and is gitignored; per-project compiler logs go to
`src/<project>/bin/build-<target>.log`.

## How a port maps onto Lime

The whole SDK is exposed as `flighthq.sdk.Sdk` statics whose names match the TypeScript exports, so
`import flighthq.sdk.Sdk.*;` makes the body of a sample a near-direct transcription. What differs is
the host glue, and it differs the same way every time:

| `ts/` | here |
| --- | --- |
| `render.<backend>.ts` builds the render state over a `<canvas>` | `onWindowCreate` builds it over the Lime window, via `GlCanvas` / `CairoCanvas` |
| `requestAnimationFrame` loop | Lime's `update(deltaTime)`, stepping the Flight app with `stepApplicationLoop` |
| `render(root)` | Lime's `render(context)` override |
| `attachPointerInput(input, container)` | Lime's `onMouseDown` / `onMouseMove` / `onMouseUp` |
| `attachKeyboardInput(input, window)` | Lime's `onKeyDown` / `onKeyUp` |
| `loadImageResourceFromUrl(...)` | `LimeAssets.image(...)` — see below |
| `loadFontFromUrl(...)` | a bundled TTF registered with the native text backend |

### Two traps worth knowing

**`loadImageResourceFromUrl` and `loadFontFromUrl` are browser-only.** The generated port drives
`new Image()`, `img.decode()` and the FontFace API through the JS global object, none of which exist
on neko. Lime already decodes PNG and TTF on every target, so assets are declared in `project.xml`,
read through `lime.utils.Assets`, and handed to Flight as raw RGBA bytes via `createBitmap` +
`createImageResourceFromBitmap` — the same path flight-hx's own examples use. That is what
`LimeAssets` in `Source/LimeCanvas.hx` wraps; every Flight call site downstream is unchanged.

**`GlCanvas.width` / `.height` must be plain fields, not properties.** Flight's GL renderer reads
them reflectively to build the viewport and the pixel→clip projection. A Haxe `(get, never)`
property compiles to a getter with no reflectable field behind it, so the read yields null, the
viewport collapses to 0×0 and the projection goes NaN — every draw is silently discarded while the
background clear still paints, which looks like a working app that renders nothing.

## Coverage

`ts/` leads; a sample exists in this tree or it does not.

| state | samples |
| --- | --- |
| ported, builds on neko + html5 | `AddingText`, `CreatingAMainLoop`, `DisplayingABitmap`, `DrawingShapes`, `TicTacToe` |
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
