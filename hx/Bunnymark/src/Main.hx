// Haxe/Lime port of ts/src/bunnymark/app.ts.
//
// No DOM backend: there is no defaultDomQuadBatchRenderer, which is the same gap that leaves
// bunnymark out of ts/'s DOM column. The stats.js overlay and the DOM counter are browser widgets
// with no Flight surface behind them, so the bunny count goes to the window title instead.
package;

import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.QuadBatch;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.MouseButton;

class Main extends Application {
  static inline final GRAVITY = 0.5;
  static inline final WIDTH = 800;
  static inline final HEIGHT = 600;
  static inline final INITIAL_COUNT = 100;
  static inline final BATCH_SIZE = 100;

  var scale:Float = 1.0;
  var drawFrame:QuadBatch->Bool;
  var ready = false;

  var quadBatch:QuadBatch;
  var bunnyWidth:Float = 0;
  var bunnyHeight:Float = 0;

  var posX:Array<Float> = [];
  var posY:Array<Float> = [];
  var speedX:Array<Float> = [];
  var speedY:Array<Float> = [];
  var addingBunnies = false;

  public function new() {
    super();
  }

  override public function onWindowCreate():Void {
    App.setAppBackend(LimeApp.createLimeAppBackend(this));
    switch (window.context.type) {
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
        throw 'bunnymark has no DOM backend (no QuadBatch renderer there); got ' + window.context.type;
    }
  }

  override public function onPreloadComplete():Void {
    final bunny = LimeAssets.image('images/wabbit_alpha.png');

    final atlas = createTextureAtlas({texture: createTexture(cast {dimension: '2d', source: bunny})});
    addTextureAtlasRegion(atlas, 0, 0, bunny.width, bunny.height);

    bunnyWidth = bunny.width;
    bunnyHeight = bunny.height;

    quadBatch = createQuadBatch();
    quadBatch.data.atlas = atlas;
    quadBatch.scaleX = scale;
    quadBatch.scaleY = scale;

    for (_ in 0...INITIAL_COUNT) addBunny();

    ready = true;
  }

  function addBunny():Void {
    resizeQuadBatch(quadBatch, posX.length + 1);
    invalidateNodeAppearance(quadBatch);
    posX.push(0);
    posY.push(0);
    speedX.push(Math.random() * 5);
    speedY.push(Math.random() * 5 - 2.5);
  }

  override public function onMouseDown(x:Float, y:Float, button:MouseButton):Void {
    addingBunnies = true;
  }

  override public function onMouseUp(x:Float, y:Float, button:MouseButton):Void {
    addingBunnies = false;
  }

  override public function update(deltaTime:Int):Void {
    if (!ready) return;

    final count:Int = quadBatch.data.instanceCount;
    final transforms = quadBatch.data.transforms;

    for (i in 0...count) {
      posX[i] += speedX[i];
      posY[i] += speedY[i];
      speedY[i] += GRAVITY;

      if (posX[i] > WIDTH - bunnyWidth) {
        speedX[i] *= -1;
        posX[i] = WIDTH - bunnyWidth;
      } else if (posX[i] < 0) {
        speedX[i] *= -1;
        posX[i] = 0;
      }

      if (posY[i] > HEIGHT - bunnyHeight) {
        speedY[i] *= -0.8;
        posY[i] = HEIGHT - bunnyHeight;
        if (Math.random() > 0.5) speedY[i] -= 3 + Math.random() * 4;
      } else if (posY[i] < 0) {
        speedY[i] = 0;
        posY[i] = 0;
      }

      transforms[i * 2] = posX[i];
      transforms[i * 2 + 1] = posY[i];
    }

    invalidateNodeAppearance(quadBatch);

    if (addingBunnies) {
      for (_ in 0...BATCH_SIZE) addBunny();
    }

    // ts/ writes the count into a fixed DOM element; the window title is the portable equivalent.
    window.title = posX.length + ' bunnies';
  }

  override public function render(context:RenderContext):Void {
    if (!ready || quadBatch == null) return;
    if (!drawFrame(quadBatch)) window.onRender.cancel();
  }
}
