// Haxe/Lime port of ts/src/adding-text (app.ts + render.webgl.ts).
//
// ts/ does `await loadFontFromUrl('fonts/KatamotzIkasi.woff', 'Katamotz Ikasi')`, which is the browser
// FontFace API and has no neko equivalent. Lime loads the TTF on every target, so the face is bundled
// in project.xml and registered with the native canvas backend under the same family name the scene
// then asks for — leaving `textFormat.font` identical to ts/.
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  static inline final FONT_NAME = 'Katamotz Ikasi';

  var scale:Float = 1.0;
  // Bound once to the chosen backend's render function, the way ts/ has render.ts re-export exactly
  // one render.<backend>.ts. Lime chooses for us, so the pick is a switch on the context type.
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var root:DisplayObject;

  public function new() {
    super();
  }

  override public function onWindowCreate():Void {
    App.setAppBackend(LimeApp.createLimeAppBackend(this));
    switch (window.context.type) {
      case DOM:
        RenderDom.init(window);
        scale = RenderDom.scale;
        drawFrame = RenderDom.render;
      case CANVAS:
        RenderCanvas.init(window);
        scale = RenderCanvas.scale;
        drawFrame = RenderCanvas.render;
      case CAIRO:
        RenderCairo.init(window);
        scale = RenderCairo.scale;
        drawFrame = RenderCairo.render;
      case OPENGL, OPENGLES, WEBGL:
        RenderGl.init(window);
        scale = RenderGl.scale;
        drawFrame = RenderGl.render;
      default:
        throw 'Unsupported Lime render context: ' + window.context.type;
    }
  }

  // Assets are only guaranteed here. onWindowCreate runs before Lime finishes preloading, so a
  // getFont/getImage there works on neko (synchronous loads) and comes back null in a browser.
  override public function onPreloadComplete():Void {
    registerBundledFont();

    root = createDisplayObject();
    root.scaleX = scale;
    root.scaleY = scale;

    final textField = createTextLabel();
    textField.data.text = 'Hello World';
    textField.data.textFormat = cast {font: FONT_NAME, size: 30, color: 0x7a0026};
    textField.x = 50;
    textField.y = 50;
    addNodeChild(root, textField);

    ready = true;
  }

  // The native text backend rasterises through its own font registry rather than a browser's, so the
  // bundled face has to be handed to it under the family name the TextFormat asks for. On html5 the
  // browser already resolves families itself and Lime has no native canvas backend to register with.
  function registerBundledFont():Void {
    #if (lime && !js && lime_cairo)
    final face = lime.utils.Assets.getFont('fonts/KatamotzIkasi.ttf');
    if (face != null) flighthq._internal.backend.NativeCanvas2dContext.registerFont(FONT_NAME, face);
    #end
  }

  override public function render(context:RenderContext):Void {
    if (!ready || root == null) return;
    // Nothing changed since the last frame: skip the draw and cancel the present, so Lime does not
    // flip to a never-drawn back buffer.
    if (!drawFrame(root)) window.onRender.cancel();
  }
}
