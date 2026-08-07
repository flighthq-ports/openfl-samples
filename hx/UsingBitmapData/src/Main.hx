// Haxe/Lime port of ts/src/using-bitmap-data/app.ts.
//
// Every bitmap operation is the Flight API as-is: captureBitmapFromImageResource, createBitmapRegion,
// applyBitmapColorScaleBias, copyBitmapPixels, copyBitmapChannel, floodFillBitmap,
// applyBitmapThreshold, createBitmapFromCanvas.
//
// The one browser-shaped step is the "drawn" tile: ts/ paints through an offscreen 2D canvas
// (document.createElement('canvas') -> getContext('2d') -> drawImage) and wraps the result with
// createBitmapFromCanvas. There is no portable canvas to hand it, and no Flight equivalent that takes
// a bitmap source, so that call is left wired to the same API and will fail outside a browser rather
// than be stubbed around.
package;

import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import lime.app.Application;
import lime.graphics.RenderContext;

typedef Placement = {?alpha:Float, ?rotation:Float, ?scaleX:Float, ?scaleY:Float};

class Main extends Application {
  var scale:Float = 1.0;
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

  override public function onPreloadComplete():Void {
    root = createDisplayObject();
    root.scaleX = scale;
    root.scaleY = scale;

    final image = LimeAssets.image('images/openfl_icon.png');
    final imageSurface = captureBitmapFromImageResource(image);
    final imageRegion = createBitmapRegion(imageSurface);
    final w:Float = image.width;
    final h:Float = image.height;

    addImage(image, 20, 20);
    addImage(image, 130, 120, {rotation: -90});

    final colorTransformed = captureBitmapFromImageResource(image);
    applyBitmapColorScaleBias(createBitmapRegion(colorTransformed), imageRegion, {
      alphaScale: 0.5,
      alphaBias: 0,
      blueScale: 1,
      blueBias: 0,
      greenScale: 0,
      greenBias: 0,
      redScale: 0.5,
      redBias: 20 / 255,
    });
    addSurface(colorTransformed, 240, 20);

    final tiled = createBitmap(w, h);
    copyBitmapPixels(createBitmapRegion(tiled, -w / 2, -h / 2, w, h), imageRegion);
    copyBitmapPixels(createBitmapRegion(tiled, -w / 2, h / 2, w, h), imageRegion);
    copyBitmapPixels(createBitmapRegion(tiled, w / 2, -h / 2, w, h), imageRegion);
    copyBitmapPixels(createBitmapRegion(tiled, w / 2, h / 2, w, h), imageRegion);
    addSurface(tiled, 350, 20);

    final composited = createBitmap(w, h, 0xeeeeeeff);
    copyBitmapPixels(createBitmapRegion(composited), imageRegion, true);
    addSurface(composited, 460, 20);

    final copiedChannel = captureBitmapFromImageResource(image);
    copyBitmapChannel(createBitmapRegion(copiedChannel, 20, 0, w, h), ImageChannel.Green, imageRegion,
      ImageChannel.Blue);
    addSurface(copiedChannel, 570, 20);

    final floodFilled = captureBitmapFromImageResource(image);
    floodFillBitmap(floodFilled, 0, 0, 0xeeeeeeff);
    addSurface(floodFilled, 20, 140);

    // The browser-shaped step described in the file header.
    final drawCanvas:Dynamic = flighthq._internal._Runtime.callProperty(
      flighthq._internal._Runtime.globalValue('document'), 'createElement', ['canvas']);
    drawCanvas.width = w;
    drawCanvas.height = h;
    final drawContext:Dynamic = drawCanvas.getContext('2d');
    if (drawContext == null || image.source == null) {
      throw 'UsingBitmapData requires a 2D canvas context and image source';
    }
    drawContext.save();
    drawContext.globalAlpha = 0.4;
    drawContext.scale(2, 1);
    drawContext.drawImage(image.source, 0, 0);
    drawContext.restore();
    addSurface(createBitmapFromCanvas(drawCanvas), 130, 140);

    // OpenFL scroll(w/2, 0): clone, then overwrite the right half with the original left half.
    final scrolled = captureBitmapFromImageResource(image);
    copyBitmapPixels(createBitmapRegion(scrolled, Math.floor(w / 2), 0, w, h), imageRegion);
    addSurface(scrolled, 240, 140);

    final thresholded = captureBitmapFromImageResource(image);
    applyBitmapThreshold(createBitmapRegion(thresholded, 40, 0, w, h), imageRegion, '>', 0x00000033,
      0x33333388, 0x000000ff);
    addSurface(thresholded, 350, 140);

    ready = true;
  }

  function addImage(source:Dynamic, x:Float, y:Float, ?opts:Placement):Void {
    final o:Placement = opts == null ? {} : opts;
    final sprite = createSprite();
    sprite.data.texture = createTexture(cast {dimension: '2d', source: source});
    sprite.x = x;
    sprite.y = y;
    sprite.alpha = o.alpha == null ? 1 : o.alpha;
    sprite.rotation = o.rotation == null ? 0 : o.rotation;
    sprite.scaleX = o.scaleX == null ? 1 : o.scaleX;
    sprite.scaleY = o.scaleY == null ? 1 : o.scaleY;
    addNodeChild(root, sprite);
  }

  function addSurface(surface:Dynamic, x:Float, y:Float, ?opts:Placement):Void {
    addImage(createImageResourceFromBitmap(surface), x, y, opts);
  }

  override public function render(context:RenderContext):Void {
    if (!ready || root == null) return;
    if (!drawFrame(root)) window.onRender.cancel();
  }
}
