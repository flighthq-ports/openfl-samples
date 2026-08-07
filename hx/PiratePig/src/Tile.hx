// ts/src/pirate-pig/tile.ts.
//
// One difference: ts/ sets `cursorElement.style.cursor` on hover, which is a DOM property. Lime
// carries the same idea on the window, so the hover cursor is set through a callback the game hands
// in rather than an element reference.
package;

import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;

typedef TileInteractionOptions = {
  ?coordScale:Float,
  ?setCursor:Bool->Void,
}

class Tile {
  public static inline final TILE_SIZE = 57;
  public static inline final TILE_STEP = TILE_SIZE + 16;

  public var obj:DisplayObject;
  public var column:Int = 0;
  public var row:Int = 0;
  public var type:Int;
  public var moving:Bool = false;
  public var removed:Bool = false;

  public function new(image:Dynamic, type:Int) {
    this.type = type;
    obj = createDisplayObject();
    setRectangle(getNodeLocalBoundsRectangle(obj), 0, 0, TILE_SIZE, TILE_SIZE);
    final sprite = createSprite();
    sprite.data.texture = createTexture(cast {dimension: '2d', source: image});
    addNodeChild(obj, sprite);
  }

  public function init():Void {
    moving = false;
    removed = false;
    obj.alpha = 1;
    obj.scaleX = 1;
    obj.scaleY = 1;
  }

  public function connectInteraction(manager:Dynamic, onDrag:Tile->Float->Float->Void,
      ?options:TileInteractionOptions):Void {
    final opts:TileInteractionOptions = options == null ? {} : options;
    final coordScale = opts.coordScale == null ? 1.0 : opts.coordScale;
    final setCursor = opts.setCursor;
    final dragThreshold = 10 * coordScale;

    // Flight hit testing is opt-in per node (default off), so the tile must enable it or pointer
    // events never reach these signals. Its local bounds, set in the constructor, are the hit region.
    setNodeHitTestEnabled(obj, true);
    final signals = enableInteractionSignals(obj);
    var startX:Float = 0;
    var startY:Float = 0;
    var isDragging = false;

    connectSignal(signals.onPointerDown, function(data:Dynamic) {
      if (moving) return;
      captureInteractionPointer(manager, data.pointerId, obj);
      startX = data.worldX;
      startY = data.worldY;
      isDragging = true;
    });

    connectSignal(signals.onPointerUp, function(data:Dynamic) {
      releaseInteractionPointer(manager, data.pointerId);
      if (!isDragging) return;
      isDragging = false;
      if (moving) return;
      final dx = data.worldX - startX;
      final dy = data.worldY - startY;
      if (Math.abs(dx) > dragThreshold || Math.abs(dy) > dragThreshold) onDrag(this, dx, dy);
    });

    if (setCursor != null) {
      connectSignal(signals.onPointerOver, function(_:Dynamic) setCursor(!moving));
      connectSignal(signals.onPointerMove, function(_:Dynamic) setCursor(!moving));
      connectSignal(signals.onPointerOut, function(_:Dynamic) setCursor(false));
    }
  }

  public function move(manager:Dynamic, duration:Float, targetX:Float, targetY:Float):Void {
    moving = true;
    final tween = createTween(manager, obj, duration, {x: targetX, y: targetY}, {ease: easeOutQuadratic});
    connectSignal(tween.onUpdate, function() invalidateNodeRender(obj));
    connectSignal(tween.onComplete, function() {
      moving = false;
      invalidateNodeRender(obj);
    });
  }

  public function removeAnimated(manager:Dynamic, tileContainer:DisplayObject):Void {
    if (removed) return;
    removed = true;

    final half = TILE_SIZE / 2;
    addNodeChildAt(tileContainer, obj, 0);

    final tween = createTween(manager, obj, 600,
      {alpha: 0, scaleX: 2, scaleY: 2, x: obj.x - half, y: obj.y - half}, {ease: easeOutQuadratic});
    connectSignal(tween.onUpdate, function() invalidateNodeRender(obj));
    connectSignal(tween.onComplete, function() {
      final parent = getNodeParent(obj);
      if (parent != null) removeNodeChild(parent, obj);
      invalidateNodeRender(tileContainer);
    });
  }

  public function removeImmediate(tileContainer:DisplayObject):Void {
    removed = true;
    final parent = getNodeParent(obj);
    if (parent != null) removeNodeChild(parent, obj);
    invalidateNodeRender(tileContainer);
  }
}
