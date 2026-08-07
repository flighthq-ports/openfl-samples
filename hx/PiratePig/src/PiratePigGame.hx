// ts/src/pirate-pig/game.ts.
package;

import Tile.TileInteractionOptions;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Shape;
import flighthq.types.TextLabel;

class PiratePigGame {
  static inline final NUM_COLUMNS = 8;
  static inline final NUM_ROWS = 8;
  static inline final CONTENT_WIDTH = 75 * NUM_COLUMNS;
  static inline final CONTENT_HEIGHT = 75 * NUM_ROWS;
  static inline final BACKGROUND_Y = 85;
  static inline final TILE_CONTAINER_X = 14;
  static inline final TILE_CONTAINER_Y = BACKGROUND_Y + 14;

  public var obj:DisplayObject;
  public var backgroundPanel:Shape;
  public var currentScale:Float = 1;
  public var currentScore:Int = 0;

  var interaction:Dynamic;
  var interactionOptions:TileInteractionOptions;
  var tileContainer:DisplayObject;
  var scoreText:TextLabel;
  var tiles:Array<Array<Tile>>;
  var usedTiles:Array<Tile> = [];
  var tileImages:Array<Dynamic>;
  var audioContext:Dynamic;
  var sounds:Array<Dynamic>;
  var manager:Dynamic;
  var needToCheckMatches:Bool = false;

  public function new(audioContext:Dynamic, manager:Dynamic, interactionManager:Dynamic,
      tileImages:Array<Dynamic>, logoImage:Dynamic, fontName:String, sounds:Array<Dynamic>,
      ?interactionOptions:TileInteractionOptions) {
    this.audioContext = audioContext;
    this.manager = manager;
    this.interaction = interactionManager;
    this.interactionOptions = interactionOptions;
    this.tileImages = tileImages;
    this.sounds = sounds;
    obj = createDisplayObject();

    scoreText = createTextLabel();
    scoreText.data.text = '0';
    scoreText.data.width = 200;
    scoreText.data.textFormat = cast {font: fontName, size: 60, color: 0x000000, align: 'right'};
    scoreText.x = CONTENT_WIDTH - 200;
    scoreText.y = 12;
    addNodeChild(obj, scoreText);

    backgroundPanel = createShape();
    backgroundPanel.y = BACKGROUND_Y;
    appendShapeBeginFill(backgroundPanel, 0xffffff, 0.4);
    appendShapeRectangle(backgroundPanel, 0, 0, CONTENT_WIDTH, CONTENT_HEIGHT);
    appendShapeEndFill(backgroundPanel);
    addNodeChild(obj, backgroundPanel);

    tileContainer = createDisplayObject();
    tileContainer.x = TILE_CONTAINER_X;
    tileContainer.y = TILE_CONTAINER_Y;
    addNodeChild(obj, tileContainer);

    tiles = [for (_ in 0...NUM_ROWS) [for (_ in 0...NUM_COLUMNS) null]];
  }

  public function newGame():Void {
    currentScore = 0;
    updateScore();

    for (row in 0...NUM_ROWS) for (col in 0...NUM_COLUMNS) removeTileAt(row, col, false);
    for (row in 0...NUM_ROWS) for (col in 0...NUM_COLUMNS) addTile(row, col, false);

    playAudioResource(audioContext, sounds[0]);
    needToCheckMatches = true;
  }

  public function onEnterFrame():Void {
    if (!needToCheckMatches) return;
    needToCheckMatches = false;

    final matched = findMatches(true).concat(findMatches(false));
    for (tile in matched) removeTileAt(tile.row, tile.column, true);

    if (matched.length > 0) {
      updateScore();
      dropTiles();
    }
  }

  public function resize(stageWidth:Float, stageHeight:Float):Void {
    obj.scaleX = 1;
    obj.scaleY = 1;

    // OpenFL sizes the game from its complete subtree, including the blurred panel's expanded bounds.
    final bounds = createRectangle();
    computeNodeRootLocalBoundsRectangle(bounds, obj);
    final scale = Math.min(Math.min((stageWidth * 0.9) / bounds.width, (stageHeight * 0.86) / bounds.height), 1);

    currentScale = scale;
    obj.scaleX = scale;
    obj.scaleY = scale;
    obj.x = stageWidth / 2 - (bounds.width * scale) / 2;

    invalidateNodeRender(obj);
  }

  // ── Private ────────────────────────────────────────────────────────────────

  function addTile(row:Int, col:Int, animate:Bool):Void {
    final type = Math.round(Math.random() * (tileImages.length - 1));

    var tile:Tile = null;
    for (t in usedTiles) {
      if (t.removed && t.type == type) {
        tile = t;
        break;
      }
    }
    if (tile == null) {
      tile = new Tile(tileImages[type], type);
      usedTiles.push(tile);
      tile.connectInteraction(interaction, function(t:Tile, dx:Float, dy:Float) {
        var targetRow = t.row;
        var targetCol = t.column;
        if (Math.abs(dx) > Math.abs(dy)) targetCol += dx < 0 ? -1 : 1;
        else targetRow += dy < 0 ? -1 : 1;
        swapTile(t, targetRow, targetCol);
      }, interactionOptions);
    }

    tile.init();
    tile.type = type;
    tile.row = row;
    tile.column = col;
    tiles[row][col] = tile;

    if (animate) {
      tile.obj.alpha = 0;
      tile.obj.x = tileX(col);
      tile.obj.y = tileY(-1);

      tile.move(manager, 150 * (row + 1), tileX(col), tileY(row));

      final target = tile.obj;
      final alphaTween = createTween(manager, target, 300, {alpha: 1},
        {delay: Math.max(0, 150 * (row - 2)), ease: easeOutQuadratic});
      connectSignal(alphaTween.onUpdate, function() invalidateNodeRender(target));
    } else {
      tile.obj.x = tileX(col);
      tile.obj.y = tileY(row);
    }

    addNodeChild(tileContainer, tile.obj);
    needToCheckMatches = true;
  }

  function dropTiles():Void {
    for (col in 0...NUM_COLUMNS) {
      var spaces = 0;

      for (i in 0...NUM_ROWS) {
        final row = NUM_ROWS - 1 - i;
        final tile = tiles[row][col];

        if (tile == null) {
          spaces++;
        } else if (spaces > 0) {
          final newRow = row + spaces;
          tile.move(manager, 150 * spaces, tileX(col), tileY(newRow));
          tile.row = newRow;
          tiles[newRow][col] = tile;
          tiles[row][col] = null;
          needToCheckMatches = true;
        }
      }

      for (i in 0...spaces) addTile(spaces - 1 - i, col, true);
    }
  }

  function findMatches(byRow:Bool, accumulateScore:Bool = true):Array<Tile> {
    final matched:Array<Tile> = [];
    final outer = byRow ? NUM_ROWS : NUM_COLUMNS;
    final inner = byRow ? NUM_COLUMNS : NUM_ROWS;

    for (o in 0...outer) {
      var run:Array<Tile> = [];

      inline function flushRun():Void {
        if (run.length >= 3) {
          if (accumulateScore) {
            final n = run.length;
            if (n > 4) playAudioResource(audioContext, sounds[3]);
            else if (n > 3) playAudioResource(audioContext, sounds[2]);
            else playAudioResource(audioContext, sounds[1]);
            currentScore += Math.round(Math.pow(n - 1, 2) * 50);
          }
          for (t in run) matched.push(t);
        }
        run = [];
      }

      for (i in 0...inner) {
        final tile = byRow ? tiles[o][i] : tiles[i][o];

        if (tile != null && !tile.moving) {
          if (run.length > 0 && tile.type != run[0].type) flushRun();
          run.push(tile);
        } else {
          if (tile != null && tile.moving) needToCheckMatches = true;
          flushRun();
        }
      }
      flushRun();
    }

    return matched;
  }

  function removeTileAt(row:Int, col:Int, animate:Bool):Void {
    final tile = tiles[row][col];
    if (tile == null) return;
    tiles[row][col] = null;

    if (animate) tile.removeAnimated(manager, tileContainer);
    else tile.removeImmediate(tileContainer);
  }

  function swapTile(tile:Tile, targetRow:Int, targetColumn:Int):Void {
    if (targetColumn < 0 || targetColumn >= NUM_COLUMNS || targetRow < 0 || targetRow >= NUM_ROWS) return;

    final targetTile = tiles[targetRow][targetColumn];
    if (targetTile == null || targetTile.moving) return;

    tiles[targetRow][targetColumn] = tile;
    tiles[tile.row][tile.column] = targetTile;

    if (findMatches(true, false).length > 0 || findMatches(false, false).length > 0) {
      final prevRow = tile.row;
      final prevCol = tile.column;
      targetTile.row = prevRow;
      targetTile.column = prevCol;
      tile.row = targetRow;
      tile.column = targetColumn;
      targetTile.move(manager, 300, tileX(prevCol), tileY(prevRow));
      tile.move(manager, 300, tileX(targetColumn), tileY(targetRow));
      needToCheckMatches = true;
    } else {
      tiles[targetRow][targetColumn] = targetTile;
      tiles[tile.row][tile.column] = tile;
    }
  }

  function updateScore():Void {
    scoreText.data.text = Std.string(currentScore);
    invalidateNodeRender(scoreText);
  }

  static inline function tileX(col:Int):Float return col * Tile.TILE_STEP;

  static inline function tileY(row:Int):Float return row * Tile.TILE_STEP;
}
