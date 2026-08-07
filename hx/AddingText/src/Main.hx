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
  var renderer:Renderer;
  var ready = false;

  var root:DisplayObject;

  public function new() {
    super();
  }

  override public function onWindowCreate():Void {
    App.setAppBackend(LimeApp.createLimeAppBackend(this));
    renderer = new Renderer(window, 0xffffffff);
    renderer.useTextLabels();
    scale = renderer.scale;

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
    if (!renderer.prepare(root)) {
      window.onRender.cancel();
      return;
    }
    renderer.draw(root);
  }
}
