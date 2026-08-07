// Haxe/Lime port of ts/src/animated-tilemap/app.ts.
//
// Despite the name the sample draws Sprites, not a Tilemap: four spritesheet players stepped from the
// frame delta, each swapping its sprite's texture to the current atlas region.
package;

import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.Sprite;
import lime.app.Application;
import lime.graphics.RenderContext;

private typedef AnimationDef = {name:String, row:Int};

class Main extends Application {
  static inline final SCALE = 4;
  static inline final TILE_SIZE = 32;
  static inline final FRAME_DURATION = 133;
  static inline final STAGE_WIDTH = 800;
  static inline final STAGE_HEIGHT = 600;

  static final ANIMATIONS:Array<AnimationDef> = [
    {name: 'snail', row: 1},
    {name: 'blob', row: 4},
    {name: 'owl', row: 5},
    {name: 'bug', row: 6},
  ];

  var scale:Float = 1.0;
  var drawFrame:Sprite->Bool;
  var ready = false;

  var root:Sprite;
  var atlas:Dynamic;
  var sheet:Dynamic;
  var sprites:Array<Sprite> = [];
  var players:Array<Dynamic> = [];
  var app:Dynamic;

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
    final source = LimeAssets.image('images/tileset.png');
    atlas = createTextureAtlas({texture: createTexture(cast {dimension: '2d', source: source, sampler: createPixelArtSampler()})});
    sheet = createSpritesheet({atlas: atlas});

    for (def in ANIMATIONS) {
      final frameIndices:Array<Int> = [];
      for (col in 0...4) {
        final atlasId:Int = atlas.regions.length;
        addTextureAtlasRegion(atlas, col * TILE_SIZE, def.row * TILE_SIZE, TILE_SIZE, TILE_SIZE);
        final frameIndex:Int = sheet.frames.length;
        sheet.frames.push(createSpritesheetFrame({id: atlasId}));
        frameIndices.push(frameIndex);
      }
      Reflect.setField(sheet.animations, def.name,
        createSpritesheetAnimation({frames: frameIndices, frameDuration: FRAME_DURATION, repeatCount: -1}));
    }

    root = createSprite();
    root.scaleX = SCALE * scale;
    root.scaleY = SCALE * scale;

    final spriteScreenSize = TILE_SIZE * SCALE;
    final totalWidth = 176 * SCALE;
    final baseX = (STAGE_WIDTH - totalWidth) / 2 / SCALE;
    final baseY = (STAGE_HEIGHT - spriteScreenSize) / 2 / SCALE;

    for (i in 0...ANIMATIONS.length) {
      final sprite = createSprite();
      sprite.data.texture = getTextureAtlasRegionTexture(atlas, i * 4);
      sprite.x = baseX + i * 48;
      sprite.y = baseY;
      invalidateNodeLocalTransform(sprite);
      addNodeChild(root, sprite);
      sprites.push(sprite);

      final player = createSpritesheetPlayer();
      playSpritesheetAnimation(player, getSpritesheetAnimation(sheet, ANIMATIONS[i].name));
      players.push(player);
    }

    app = createApplication();
    connectSignal(app.onUpdate, function(delta:Float) {
      for (i in 0...players.length) {
        if (updateSpritesheetPlayer(players[i], delta)) {
          final frame = getSpritesheetPlayerFrame(players[i], sheet);
          if (frame != null) sprites[i].data.texture = getTextureAtlasRegionTexture(atlas, frame.id);
        }
      }
    });

    ready = true;
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
