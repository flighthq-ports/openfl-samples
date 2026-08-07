// Haxe/Lime port of ts/src/pirate-pig/app.ts, with game.ts and tile.ts as PiratePigGame.hx and
// Tile.hx alongside it.
//
// Two substitutions beyond the usual host glue:
//   * assets come from the bundled corpus through Lime rather than loadImageResourceFromUrl /
//     loadFontFromUrl, so the scene is built in onPreloadComplete;
//   * ts/ drives layout and pause/resume through createApplicationWindow + attachWindowResize /
//     attachWindowVisibility, which bind to DOM elements. Lime reports the same events on the
//     Application itself (onWindowResize / onWindowActivate / onWindowDeactivate).
//
// Audio is wired to the Flight API as written — loadAudioResourceFromUrls needs an AudioContext,
// which the generated port takes from the JS global. That has no counterpart on neko and no Lime
// host in flight-hx, so this sample is expected to fail there. Left unstubbed on purpose.
package;

import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Sprite;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  var scale:Float = 1.0;
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var manager:Dynamic;
  var root:DisplayObject;
  var background:Sprite;
  var footer:Sprite;
  var game:PiratePigGame;
  var app:Dynamic;
  var refreshBackgroundBlur:Void->Void = function() {};
  var applyBlur:Dynamic->(Void->Void);

  var bgWidth:Float = 1;
  var bgHeight:Float = 1;
  var footerWidth:Float = 0;
  var footerHeight:Float = 0;

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
        applyBlur = RenderDom.applyBackgroundBlur;
      case CANVAS:
        RenderCanvas.init(window);
        scale = RenderCanvas.scale;
        drawFrame = RenderCanvas.render;
        applyBlur = RenderCanvas.applyBackgroundBlur;
      case CAIRO:
        RenderCairo.init(window);
        scale = RenderCairo.scale;
        drawFrame = RenderCairo.render;
        applyBlur = RenderCairo.applyBackgroundBlur;
      case OPENGL, OPENGLES, WEBGL:
        RenderGl.init(window);
        scale = RenderGl.scale;
        drawFrame = RenderGl.render;
        applyBlur = RenderGl.applyBackgroundBlur;
      default:
        throw 'Unsupported Lime render context: ' + window.context.type;
    }
  }

  override public function onPreloadComplete():Void {
    final audioContext = ensureAudioContext();

    final bgImage = LimeAssets.image('images/background_tile.png');
    final footerImage = LimeAssets.image('images/center_bottom.png');
    final logoImage = LimeAssets.image('images/logo.png');
    final tileImages = [
      for (name in ['game_bear', 'game_bunny_02', 'game_carrot', 'game_lemon', 'game_panda', 'game_piratePig'])
        LimeAssets.image('images/' + name + '.png')
    ];
    registerBundledFont();

    final sounds = [
      for (name in ['theme', 'sound3', 'sound4', 'sound5'])
        loadAudioResourceFromUrls(audioContext, [{url: 'sounds/' + name + '.ogg'}])
    ];

    bgWidth = bgImage.width;
    bgHeight = bgImage.height;
    footerWidth = footerImage.width;
    footerHeight = footerImage.height;

    registerHitTest(DisplayObjectKind, hitTestGraphLocalBounds);

    manager = createTweenManager();
    root = createDisplayObject();
    root.scaleX = scale;
    root.scaleY = scale;

    background = createSprite();
    background.data.texture = createTexture(cast {dimension: '2d', source: bgImage});
    addNodeChild(root, background);

    footer = createSprite();
    footer.data.texture = createTexture(cast {dimension: '2d', source: footerImage});
    addNodeChild(root, footer);

    final interactionManager = createInteractionManager(root);
    game = new PiratePigGame(audioContext, manager, interactionManager, tileImages, logoImage,
      FONT_NAME, sounds, {
        coordScale: scale,
        // ts/ writes container.style.cursor; Lime carries the same idea on the window.
        setCursor: function(pointer:Bool) window.cursor = pointer ? POINTER : DEFAULT,
      });

    final logo = createSprite();
    logo.data.texture = createTexture(cast {dimension: '2d', source: logoImage});
    addNodeChild(game.obj, logo);

    addNodeChild(root, game.obj);

    // Blur the white score panel (OpenFL: Background.filters = [new BlurFilter(10, 10)]).
    refreshBackgroundBlur = applyBlur(game.backgroundPanel);

    app = createApplication();
    connectSignal(app.onUpdate, function(delta:Float) {
      updateTweens(manager, delta);
      game.onEnterFrame();
    });

    ready = true;
    resize(window.width, window.height);
    game.newGame();
  }

  static inline final FONT_NAME = 'FreebooterUpdated';

  function registerBundledFont():Void {
    #if (lime && !js && lime_cairo)
    final face = lime.utils.Assets.getFont('fonts/FreebooterUpdated.ttf');
    if (face != null) flighthq._internal.backend.NativeCanvas2dContext.registerFont(FONT_NAME, face);
    #end
  }

  // ts/ constructs `new AudioContext()`; the generated port reaches the same global.
  function ensureAudioContext():Dynamic {
    return flighthq._internal._Runtime.construct(flighthq._internal._Runtime.globalValue('AudioContext'), []);
  }

  function resize(w:Float, h:Float):Void {
    if (!ready) return;

    background.scaleX = w / bgWidth;
    background.scaleY = h / bgHeight;
    invalidateNodeRender(background);

    game.resize(w, h);

    footer.scaleX = game.currentScale;
    footer.scaleY = game.currentScale;
    footer.x = w / 2 - (footerWidth * footer.scaleX) / 2;
    footer.y = h - footerHeight * footer.scaleY;
    invalidateNodeRender(footer);

    // Re-bake the cached background blur for the new layout.
    refreshBackgroundBlur();
  }

  override public function onWindowResize(width:Int, height:Int):Void {
    resize(width, height);
  }

  override public function update(deltaTime:Int):Void {
    if (!ready) return;
    stepApplicationLoop(app, deltaTime);
  }

  override public function render(context:RenderContext):Void {
    if (!ready || root == null) return;
    if (!drawFrame(root)) window.onRender.cancel();
  }
}
