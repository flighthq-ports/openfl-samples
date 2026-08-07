// Haxe/Lime port of ts/src/displaying-a-bitmap (app.ts + render.webgl.ts).
//
// One substitution matters beyond the usual browser glue. ts/ calls
// `await loadImageResourceFromUrl('images/openfl_icon_large.png')`, and that function is browser-only:
// the generated port drives `new Image()` and `img.decode()` through the JS global object, which does
// not exist on neko. Lime already decodes PNG on every target, so the asset is declared in project.xml
// and read through `lime.utils.Assets`, then handed to Flight as an ImageResource built from raw RGBA
// bytes — the same `createImageResourceFromBitmap` path flight-hx's own examples use. Every Flight call
// site downstream is unchanged.
import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  var scale:Float = 1.0;
  var renderer:Renderer;
  var ready = false;

  var main:DisplayObject;

  public function new() {
    super();
  }

  override public function onWindowCreate():Void {
    App.setAppBackend(LimeApp.createLimeAppBackend(this));
    renderer = new Renderer(window, 0xffffffff);
    renderer.useSprites();
    scale = renderer.scale;

    main = createDisplayObject();
    main.scaleX = scale;
    main.scaleY = scale;

    final bitmap = createSprite();

    final image = LimeAssets.image('images/openfl_icon_large.png');
    bitmap.data.texture = createTexture(cast {dimension: '2d', source: image});
    bitmap.x = (800 - imageWidth(image)) / 2;
    bitmap.y = (600 - imageHeight(image)) / 2;
    addNodeChild(main, bitmap);

    ready = true;
  }

  static inline function imageWidth(image:Dynamic):Float return image.width;

  static inline function imageHeight(image:Dynamic):Float return image.height;

  override public function render(context:RenderContext):Void {
    if (!ready || main == null) return;
    if (!renderer.prepare(main)) {
      window.onRender.cancel();
      return;
    }
    renderer.draw(main);
  }
}
