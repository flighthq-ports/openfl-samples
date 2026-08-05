# Haxe / Lime port

Not yet written. This tree will hold the same samples built against
[flight-hx](https://github.com/flighthq/flight-hx) — the Flight SDK mechanically ported to Haxe —
running on Lime.

The point is not a second copy of the TypeScript samples. `ts/` is the web story; this tree is the
same sample compiling natively to C++ and running on Windows, macOS, Linux, iOS, and Android. That
is the half of Flight's reach the TypeScript tree cannot show.

## Intended shape

```
hx/
  src/DisplayingABitmap/
    project.xml        standalone Lime app, own <assets> lines
    Source/Main.hx
```

One Lime project per sample, mirroring `ts/src/<sample>/`. Directory names are PascalCase because
they are also the Haxe class names — which is why nothing derives them from the kebab-case ids:
`glsl-bitmap` would mechanically produce `GlslBitmap`, not `GLSLBitmap`.

Assets come from the shared `../assets/` corpus, named per project in `<assets>` tags. There is no
generated manifest to parse — the same reason `ts/` names its assets inline.

## Open questions before this starts

**How Lime binds to Flight.** Lime supplies the window and GL context; Flight needs an equivalent
of `createGlRenderState` over it. If that binding does not exist yet, this tree is one integration
plus N samples, and the integration should be proven on a single sample before the rest follow.

**Which samples.** `ts/` leads for now. A sample exists in this tree or it does not; nothing
declares an intended set, so the trees can diverge without any file being wrong.

**Debug builds.** `#if debug` is the direct analogue of the `import.meta.env.DEV` guard the
TypeScript tree uses in `ts/dev/explain.ts`, so both trees stay diagnosable the same way.
