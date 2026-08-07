// Haxe/Lime port of ts/src/compare-bitmap-data/app.ts.
//
// Every image comes from the bundled corpus through Lime rather than loadImageResourceFromUrl. The
// sample's subject — captureBitmapFromImageResource, compareBitmap and its sentinel return values —
// is the same Flight surface ts/ uses.
package;

import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  static inline final SIZE = 32;
  static inline final SPACING = 10;
  static inline final CELL = SIZE + SPACING;
  static inline final HEADER_OFFSET = SIZE + 20;

  static final SOURCE_NAMES = [
    'checkers', 'checkers_alpha', 'noise1', 'noise2', 'red_ball',
    'red_ball_alpha', 'red_ball_half_alpha', 'yellow_ball', 'rectangle', 'rectangle2',
  ];

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

    inline function indicator(name:String):Dynamic return LimeAssets.image('images/' + SIZE + '/' + name + '.png');

    final sourceImages = [for (name in SOURCE_NAMES) indicator(name)];
    final indicator0 = indicator('0');
    final indicatorMinus1 = indicator('minus1');
    final indicatorMinus3 = indicator('minus3');
    final indicatorMinus4 = indicator('minus4');
    final indicatorNull = indicator('null');
    final indicatorDisposed = indicator('disposed');
    final indicatorError = indicator('error');

    final sourceBitmaps = [for (image in sourceImages) captureBitmapFromImageResource(image)];

    final entries = sourceImages.concat([indicatorNull, indicatorDisposed]);
    final count = entries.length;

    for (col in 0...count) addImage(entries[col], HEADER_OFFSET + col * CELL, 10);
    for (row in 0...count) addImage(entries[row], 10, HEADER_OFFSET + row * CELL);

    // OpenFL BitmapData.compare returns a diff BitmapData when the sizes match and the pixels differ,
    // 0 when identical, -1 for a non-BitmapData, -2 disposed, -3 differing widths, -4 differing heights.
    for (row in 0...count) {
      final rowBitmap = row < sourceBitmaps.length ? sourceBitmaps[row] : null;

      for (col in 0...count) {
        final x = HEADER_OFFSET + col * CELL;
        final y = HEADER_OFFSET + row * CELL;
        final colBitmap = col < sourceBitmaps.length ? sourceBitmaps[col] : null;

        if (rowBitmap == null && colBitmap == null) {
          addImage(indicatorError, x, y);
          continue;
        }
        if (rowBitmap == null || colBitmap == null) {
          addImage(indicatorMinus1, x, y);
          continue;
        }

        final rowImg = sourceImages[row];
        final colImg = sourceImages[col];

        if (rowImg.width != colImg.width) {
          addImage(indicatorMinus3, x, y);
          continue;
        }
        if (rowImg.height != colImg.height) {
          addImage(indicatorMinus4, x, y);
          continue;
        }

        final diff = compareBitmap(rowBitmap, colBitmap);
        if (diff == null) addImage(indicator0, x, y);
        else addImage(createImageResourceFromBitmap(diff), x, y);
      }
    }

    ready = true;
  }

  function addImage(image:Dynamic, x:Float, y:Float):Void {
    final sprite = createSprite();
    sprite.data.texture = createTexture(cast {dimension: '2d', source: image});
    sprite.x = x;
    sprite.y = y;
    addNodeChild(root, sprite);
  }

  override public function render(context:RenderContext):Void {
    if (!ready || root == null) return;
    if (!drawFrame(root)) window.onRender.cancel();
  }
}
