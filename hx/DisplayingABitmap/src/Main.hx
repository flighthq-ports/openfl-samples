// Haxe/Lime port of ts/src/displaying-a-bitmap (app.ts + render.webgl.ts).
//
// One substitution matters beyond the usual browser glue. ts/ calls
// `await loadImageResourceFromUrl('images/openfl_icon_large.png')`, and that function is browser-only:
// the generated port drives `new Image()` and `img.decode()` through the JS global object, which does
// not exist on neko. Lime already decodes PNG on every target, so the asset is declared in project.xml
// and read through `lime.utils.Assets`, then handed to Flight as an ImageResource built from raw RGBA
// bytes — the same `createImageResourceFromBitmap` path flight-hx's own examples use. Every Flight call
// site downstream is unchanged.
//
// The scene is built in onPreloadComplete rather than onWindowCreate. Lime loads assets
// asynchronously on html5 and only guarantees them once preloading finishes; onWindowCreate runs
// before that, so reading the image there works on neko (synchronous loads) and throws in a browser.
import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  var scale:Float = 1.0;
  // Bound once to the chosen backend's render function, the way ts/ has render.ts re-export exactly
  // one render.<backend>.ts. Lime chooses for us, so the pick is a switch on the context type.
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var main:DisplayObject;

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

  // Assets are guaranteed here, not in onWindowCreate.
  override public function onPreloadComplete():Void {
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
    // Nothing changed since the last frame: skip the draw and cancel the present, so Lime does not
    // flip to a never-drawn back buffer.
    if (!drawFrame(main)) window.onRender.cancel();
  }
}
