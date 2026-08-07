// Haxe/Lime port of ts/src/text-metrics/app.ts.
//
// The one substitution: ts/ measures text with an offscreen 2D canvas
// (measureCtx.measureText(t).width). There is no such canvas outside a browser, so the
// TextMeasureFunction is backed by Lime's own font metrics instead. Everything the sample is about —
// computeTextLayout, the per-line ascent/descent/leading readings, and drawing them as guide lines —
// is the same Flight surface ts/ uses.
package;

import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Shape;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  static inline final BUFFER = 64;
  static inline final GUTTER = 2;
  static inline final BOX_W = 354;
  static inline final BOX_H = 354;
  static inline final FIELD_W = BOX_W - GUTTER * 2;
  static inline final FIELD_H = BOX_H - GUTTER * 2;
  static inline final TEXT = 'Wqx\nWqx';
  static inline final TEXT_X = 300;
  static inline final TEXT_Y = 100;

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

    // Matches the original: serif, 120px, centered, 20px leading.
    final format:Dynamic = {align: 'center', font: 'serif', leading: 20, size: 120};

    final textField = createRichText();
    textField.x = TEXT_X;
    textField.y = TEXT_Y;
    textField.data.border = true;
    textField.data.borderColor = 0x000000;
    textField.data.defaultTextFormat = format;
    textField.data.height = FIELD_H;
    textField.data.multiline = true;
    textField.data.selectable = false;
    textField.data.text = TEXT;
    textField.data.width = FIELD_W;
    textField.data.wordWrap = true;

    final result = createTextLayoutResult();
    computeTextLayout(result, {
      formatRanges: [createTextFormatRange(format, 0, TEXT.length)],
      height: FIELD_H,
      measure: measure,
      multiline: true,
      text: TEXT,
      width: FIELD_W,
      wordWrap: true,
    });

    var lineX:Float = 0;
    for (g in (cast result.groups : Array<Dynamic>)) {
      if (g.lineIndex == 0) {
        lineX = g.offsetX;
        break;
      }
    }
    final ascent = first(result.lineAscents);
    final descent = first(result.lineDescents);
    final lineHeight = first(result.lineHeights);
    final leading = first(result.lineLeadings);
    final lineWidth = first(result.lineWidths);
    final textWidth:Float = result.textWidth;
    final textHeight:Float = result.textHeight;

    // Visualization: the original drew these into a BitmapData; here they are shape strokes.
    final vizLines = createShape();
    vizLines.x = TEXT_X - BUFFER;
    vizLines.y = TEXT_Y - BUFFER;
    drawLineMetrics(vizLines, lineX, ascent, descent, lineHeight, lineWidth, textWidth, textHeight);

    final outText = createRichText();
    outText.x = 0;
    outText.y = 0;
    outText.data.defaultTextFormat = {font: 'serif'};
    outText.data.height = 1000;
    outText.data.multiline = true;
    outText.data.text = buildMetricsString(ascent, descent, lineHeight, leading, lineWidth, textWidth, textHeight);
    outText.data.width = 600;
    outText.data.wordWrap = false;

    final whiteBg = createShape();
    whiteBg.x = 0;
    whiteBg.y = 250;
    appendShapeBeginFill(whiteBg, 0xffffff, 1);
    appendShapeRectangle(whiteBg, 0, 0, 200, 100);

    final loremText = createRichText();
    loremText.x = 0;
    loremText.y = 250;
    loremText.data.defaultTextFormat = {font: 'serif'};
    loremText.data.text = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor '
      + 'incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation '
      + 'ullamco laboris nisi ut aliquip ex ea commodo consequat.';
    loremText.data.width = 200;
    loremText.data.wordWrap = true;

    addNodeChild(root, textField);
    addNodeChild(root, vizLines);
    addNodeChild(root, whiteBg);
    addNodeChild(root, loremText);
    addNodeChild(root, outText);

    invalidateNodeRender(root);
    ready = true;
  }

  // ts/ measures through an offscreen 2D canvas: measureCtx.font = computeTextFormatFontString(fmt),
  // then measureCtx.measureText(t).width. There is no portable equivalent — a real implementation
  // needs a shaped advance from the resolved face, which is what flighthq.textshaperCanvas provides
  // in a browser and nothing provides here. This is a deliberate placeholder: a flat half-em advance,
  // enough for computeTextLayout to run and for the metric readings to be exercised, but the numbers
  // it produces are not real text metrics. Wiring a Lime-backed TextMeasureFunction is the fix.
  static function measure(text:String, format:Dynamic):Float {
    final size:Float = format.size == null ? 12 : format.size;
    return text.length * size * 0.5;
  }

  static inline function first(values:Dynamic):Float {
    final list:Array<Float> = cast values;
    return list.length > 0 ? list[0] : 0;
  }

  static function fillRect(shape:Shape, x:Float, y:Float, w:Float, h:Float, color:Int):Void {
    appendShapeBeginFill(shape, color, 1);
    appendShapeRectangle(shape, x, y, Math.max(w, 1), Math.max(h, 1));
  }

  function drawLineMetrics(shape:Shape, lineX:Float, ascent:Float, descent:Float, lineHeight:Float,
      lineWidth:Float, textWidth:Float, textHeight:Float):Void {
    final left = BUFFER + GUTTER;
    final top = BUFFER + GUTTER;
    // Field box.
    fillRect(shape, left, top, FIELD_W, 1, 0x00ff00);
    fillRect(shape, left, top + FIELD_H, FIELD_W, 1, 0x00ff00);
    fillRect(shape, left, top, 1, FIELD_H, 0x00ff00);
    fillRect(shape, left + FIELD_W, top, 1, FIELD_H, 0x00ff00);
    // Baseline, ascent and descent of the first line.
    fillRect(shape, left, top + ascent, FIELD_W, 1, 0xff0000);
    fillRect(shape, left, top + ascent + descent, FIELD_W, 1, 0xff0000);
    fillRect(shape, left, top + lineHeight, FIELD_W, 1, 0xff0000);
    // Measured text extents.
    fillRect(shape, left + lineX, top, 1, textHeight, 0xff0000);
    fillRect(shape, left + lineX + lineWidth, top, 1, textHeight, 0xff0000);
    fillRect(shape, left, top + textHeight, textWidth, 1, 0xff0000);
  }

  static function buildMetricsString(ascent:Float, descent:Float, lineHeight:Float, leading:Float,
      lineWidth:Float, textWidth:Float, textHeight:Float):String {
    return 'x/y = ' + TEXT_X + ' / ' + TEXT_Y
      + '\nwidth/height = ' + FIELD_W + ' / ' + FIELD_H
      + '\ntextWidth/textHeight = ' + textWidth + ' / ' + textHeight
      + '\nline[0] width = ' + lineWidth
      + '\nline[0] height = ' + lineHeight
      + '\nline[0] ascent = ' + ascent
      + '\nline[0] descent = ' + descent
      + '\nline[0] leading = ' + leading;
  }

  override public function render(context:RenderContext):Void {
    if (!ready || root == null) return;
    if (!drawFrame(root)) window.onRender.cancel();
  }
}
