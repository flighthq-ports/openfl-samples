// Lime window -> Flight render-target adapters, plus the portable asset loader.
//
// ts/ gets these for free from the browser: a <canvas> element is already what createGlRenderState
// and createCanvasRenderState expect, and images arrive through loadImageResourceFromUrl. Neither
// holds outside a browser, so each project carries this small shim. It is copied per project rather
// than shared, for the same reason ts/ repeats render.<backend>.ts per sample: a sample is meant to
// be liftable on its own.
package;

import flighthq.sdk.Sdk.*;
import flighthq.types.Bitmap;
import lime.ui.Window;

// Minimal GL canvas adapter over the Lime window, matching the shape createGlRenderState expects.
// @:keep — Flight reaches this reflectively (getContext/width/height via Reflect), so full DCE would
// strip the members and the reflective read would fail at runtime rather than at compile time.
@:keep
class GlCanvas {
  // Read reflectively by Flight's GL renderer to build both the viewport and the pixel->clip
  // projection, so these must be plain fields. A Haxe `(get, never)` property compiles to a getter
  // with no reflectable field behind it: the read returns null, the viewport collapses to 0x0 and
  // the projection goes NaN, which silently discards every draw while the background clear still
  // shows.
  public var width:Int = 0;
  public var height:Int = 0;

  final window:Window;
  final context:Dynamic;

  public function new(window:Window) {
    this.window = window;
    context = resolveContext(window);
    if (context == null) throw 'Flight samples require a hardware OpenGL/WebGL window.';
    syncSize();
    window.onResize.add((_, _) -> syncSize());
  }

  public function getContext(contextId:String, ?attributes:Dynamic):Dynamic {
    return context;
  }

  function syncSize():Void {
    width = Std.int(window.width * window.scale);
    height = Std.int(window.height * window.scale);
  }

  static function resolveContext(window:Window):Dynamic {
    final renderContext:Dynamic = window.context;
    if (renderContext == null) return null;
    final webgl2 = renderContext.webgl2;
    return webgl2 == null ? renderContext.webgl : webgl2;
  }
}

// The cairo counterpart of GlCanvas, for Lime's software window.
@:keep
class CairoCanvas {
  public var width:Int = 0;
  public var height:Int = 0;

  final window:Window;
  final context:Dynamic;

  public function new(window:Window) {
    this.window = window;
    #if (lime && !js && lime_cairo)
    // Lime can recreate the window cairo at render-surface lock, so hand the context a live
    // provider rather than one cached instance.
    final windowRef = window;
    context = new flighthq._internal.backend.NativeCanvas2dContext(window.context.cairo, () -> windowRef.context.cairo);
    #else
    context = null;
    #end
    syncSize();
    window.onResize.add((_, _) -> syncSize());
  }

  public function getContext(contextId:String, ?attributes:Dynamic):Dynamic {
    return context;
  }

  function syncSize():Void {
    width = Std.int(window.width * window.scale);
    height = Std.int(window.height * window.scale);
    #if (lime && !js && lime_cairo)
    (cast context : flighthq._internal.backend.NativeCanvas2dContext).resize(width, height);
    #end
  }
}

// The portable stand-in for ts/'s loadImageResourceFromUrl / loadFontFromUrl.
//
// Those two are browser-only in the generated port: they drive `new Image()` and the FontFace API
// through the JS global object, which does not exist on neko. Lime already decodes PNG and TTF on
// every target, so assets are declared in project.xml and read through lime.utils.Assets, then
// handed to Flight as raw bytes. Every Flight call site downstream is unchanged.
class LimeAssets {
  // Decode a bundled image into a Flight ImageResource backed by real RGBA bytes. The `data` upload
  // path (source stays null) is what the GL renderer's 9-argument texImage2D overload wants; handing
  // it a bare {width, height} object instead lands on the DOM-element overload and is rejected.
  public static function image(id:String):Dynamic {
    final source = lime.utils.Assets.getImage(id);
    if (source == null) throw 'Missing asset: ' + id;
    return fromLimeImage(source);
  }

  public static function fromLimeImage(source:lime.graphics.Image):Dynamic {
    final bitmap:Bitmap = createBitmap(source.width, source.height);
    final pixels = source.getPixels(new lime.math.Rectangle(0, 0, source.width, source.height), RGBA32);
    for (i in 0...source.width * source.height * 4) bitmap.data[i] = pixels.get(i);
    return createImageResourceFromBitmap(bitmap);
  }

  // Raw bytes for the formats Flight parses itself (SWF, spritesheet JSON, sounds).
  public static function bytes(id:String):haxe.io.Bytes {
    final data = lime.utils.Assets.getBytes(id);
    if (data == null) throw 'Missing asset: ' + id;
    return data;
  }

  public static function text(id:String):String {
    final data = lime.utils.Assets.getText(id);
    if (data == null) throw 'Missing asset: ' + id;
    return data;
  }
}
