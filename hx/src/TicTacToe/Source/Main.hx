// Haxe/Lime port of ts/src/tic-tac-toe (app.ts + render.webgl.ts).
//
// ts/ routes clicks through createInputManager + attachPointerInput(input, container), which binds to
// a DOM element. Lime delivers pointer events on the window itself, so the onPointerDown handler moves
// verbatim into Lime's onMouseDown override; the board logic below is unchanged.
import LimeCanvas.CairoCanvas;
import LimeCanvas.GlCanvas;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Shape;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.MouseButton;

class Main extends Application {
  static inline final BOARD_X = 10;
  static inline final BOARD_Y = 10;
  static inline final CELL_SIZE = 50;
  static inline final BOARD_SIZE = CELL_SIZE * 3;

  static final WINNING_LINES = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];

  var scale:Float = 1.0;
  var renderState:Dynamic;
  var usingCairo = false;
  var ready = false;

  var root:DisplayObject;
  var tileShapes:Array<Shape> = [];
  // 'X' | 'O' | null in ts/; null-able String here carries the same three states.
  var players:Array<Null<String>> = [for (_ in 0...9) null];
  var winners:Array<Bool> = [for (_ in 0...9) false];
  var turn = 0;
  var hasWinner = false;

  public function new() {
    super();
  }

  override public function onWindowCreate():Void {
    App.setAppBackend(LimeApp.createLimeAppBackend(this));
    switch (window.context.type) {
      case CAIRO:
        usingCairo = true;
      case OPENGL, OPENGLES, WEBGL:
      default:
        throw 'Flight samples require an OpenGL/WebGL or cairo render context.';
    }
    scale = window.scale;

    if (usingCairo) {
      renderState = createCanvasRenderState(new CairoCanvas(window), {
        pixelRatio: scale,
        sceneGraphSyncPolicy: 'requiresInvalidation',
        backgroundColor: 0xffffffff,
      });
      registerRenderer(renderState, ShapeKind, defaultCanvasShapeRenderer);
      registerCanvasShapeCommands(renderState, defaultCanvasShapeCommands);
    } else {
      renderState = createGlRenderState(new GlCanvas(window), {
        pixelRatio: scale,
        sceneGraphSyncPolicy: 'requiresInvalidation',
        backgroundColor: 0xffffffff,
      });
      registerRenderer(renderState, ShapeKind, defaultGlShapeRenderer);
      registerGlShapeCommands(renderState, defaultGlShapeCommands);
      registerGlShapeRasterizer(renderState, createCanvasShapeRasterizer(createCanvasTextureResolvers()));
      registerGlStandardMaterial(renderState);
    }

    root = createDisplayObject();
    root.scaleX = scale;
    root.scaleY = scale;

    final board = createShape();
    appendShapeLineStyle(board, 4, 0x000000);
    appendShapeMoveTo(board, 50, 0);
    appendShapeLineTo(board, 50, 150);
    appendShapeMoveTo(board, 100, 0);
    appendShapeLineTo(board, 100, 150);
    appendShapeMoveTo(board, 0, 50);
    appendShapeLineTo(board, 150, 50);
    appendShapeMoveTo(board, 0, 100);
    appendShapeLineTo(board, 150, 100);
    board.x = BOARD_X;
    board.y = BOARD_Y;
    invalidateNodeLocalTransform(board);
    addNodeChild(root, board);

    for (index in 0...9) {
      final tile = createShape();
      tile.x = BOARD_X + (index % 3) * CELL_SIZE;
      tile.y = BOARD_Y + Math.floor(index / 3) * CELL_SIZE;
      invalidateNodeLocalTransform(tile);
      addNodeChild(root, tile);
      tileShapes.push(tile);
    }

    ready = true;
  }

  function redrawTile(index:Int):Void {
    final tile = tileShapes[index];
    final player = players[index];

    clearShapeCommands(tile);
    if (player == null) {
      invalidateNodeRender(tile);
      return;
    }

    final color = winners[index] ? 0xff9900 : (player == 'X' ? 0x990000 : 0x000099);
    appendShapeLineStyle(tile, 12, color);

    if (player == 'X') {
      appendShapeMoveTo(tile, 11, 11);
      appendShapeLineTo(tile, 39, 39);
      appendShapeMoveTo(tile, 11, 39);
      appendShapeLineTo(tile, 39, 11);
    } else {
      appendShapeCircle(tile, 25, 25, 14);
    }

    invalidateNodeRender(tile);
  }

  function resetBoard():Void {
    for (i in 0...9) {
      players[i] = null;
      winners[i] = false;
    }
    turn = 0;
    hasWinner = false;
    for (i in 0...tileShapes.length) redrawTile(i);
  }

  function checkWinner():Void {
    for (line in WINNING_LINES) {
      final a = line[0], b = line[1], c = line[2];
      final player = players[a];
      if (player != null && player == players[b] && player == players[c]) {
        hasWinner = true;
        winners[a] = true;
        winners[b] = true;
        winners[c] = true;
        redrawTile(a);
        redrawTile(b);
        redrawTile(c);
        break;
      }
    }
  }

  // ts/'s connectSignal(input.onPointerDown, ...), on Lime's own pointer lane.
  override public function onMouseDown(x:Float, y:Float, button:MouseButton):Void {
    if (!ready) return;
    final bx = x - BOARD_X;
    final by = y - BOARD_Y;
    if (bx < 0 || by < 0 || bx >= BOARD_SIZE || by >= BOARD_SIZE) return;

    if (hasWinner) {
      resetBoard();
      return;
    }

    final column = Math.floor(bx / CELL_SIZE);
    final row = Math.floor(by / CELL_SIZE);
    final index = row * 3 + column;
    if (players[index] != null) return;

    players[index] = turn % 2 == 0 ? 'X' : 'O';
    turn++;
    redrawTile(index);
    checkWinner();
  }

  override public function render(context:RenderContext):Void {
    if (!ready || root == null) return;
    if (!prepareScene2DRender(renderState, root)) {
      window.onRender.cancel();
      return;
    }
    if (usingCairo) {
      renderCanvasBackground(renderState);
      renderCanvasScene2D(renderState, root);
    } else {
      renderGlBackground(renderState);
      renderGlScene2D(renderState, root);
    }
  }
}
