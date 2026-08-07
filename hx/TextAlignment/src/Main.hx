// Haxe/Lime port of ts/src/text-alignment/app.ts.
//
// ts/ pulls the two embedded faces through loadFontFromUrl (the browser FontFace API) and the 18
// comparison screenshots through loadImageResourceFromUrl. Both are bundled here and read through
// Lime instead; the faces are registered with the native text backend under the same family names
// the TextFormats ask for, so getFont() below still returns a name the layout resolves.
package;

import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.RichText;
import flighthq.types.Sprite;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;

class Main extends Application {
  static inline final MAX_DEMO = 5;
  static inline final TEXT = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod '
    + 'tempor incididunt ut labore et dolore magna aliqua.';

  static inline final FONT_LIBERATION = 'Liberation Serif Regular';
  static inline final FONT_NOKIA = 'Nokia Cellphone FC Small';

  static final ALIGNS = ['center', 'left', 'right', 'justify'];
  static final RENDERERS = ['flash', 'legacy', 'html5'];

  var scale:Float = 1.0;
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var root:DisplayObject;
  var comparison:Sprite;
  var label:RichText;
  var instructions:RichText;
  var textFields:Array<RichText> = [];
  var comparisonImages:Map<String, Dynamic> = new Map();

  var comparisonAlpha:Float = 1;
  var comparisonRenderer:String = null;
  var demo = 0;

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
    registerBundledFonts();

    for (renderer in RENDERERS) {
      for (i in 0...MAX_DEMO + 1) {
        final key = renderer + i;
        comparisonImages.set(key, LimeAssets.image('img/' + key + '.png'));
      }
    }

    root = createDisplayObject();
    root.scaleX = scale;
    root.scaleY = scale;

    comparison = createSprite();
    comparison.alpha = 0;
    addNodeChild(root, comparison);

    label = createRichText();
    label.data.defaultTextFormat = {font: 'serif'};
    label.data.text = 'HTML5';
    label.data.width = 220;
    addNodeChild(root, label);

    for (y in [50, 175, 300, 425]) {
      final field = createRichText();
      field.x = 50;
      field.y = y;
      field.data.border = true;
      field.data.borderColor = 0x000000;
      field.data.height = 100;
      field.data.multiline = true;
      field.data.selectable = false;
      field.data.text = TEXT;
      field.data.width = 700;
      field.data.wordWrap = true;
      addNodeChild(root, field);
      textFields.push(field);
    }

    instructions = createRichText();
    instructions.y = 20;
    instructions.data.defaultTextFormat = {font: 'serif'};
    instructions.data.width = 800;
    addNodeChild(root, instructions);

    ready = true;
    showDemo(0);
  }

  // The native text backend rasterises through its own registry rather than a browser's, so the
  // bundled faces are handed to it under the family names the TextFormats ask for.
  function registerBundledFonts():Void {
    #if (lime && !js && lime_cairo)
    final liberation = lime.utils.Assets.getFont('fonts/LiberationSerif-Regular.ttf');
    if (liberation != null) {
      flighthq._internal.backend.NativeCanvas2dContext.registerFont(FONT_LIBERATION, liberation);
    }
    final nokia = lime.utils.Assets.getFont('fonts/nokiafc22.ttf');
    if (nokia != null) flighthq._internal.backend.NativeCanvas2dContext.registerFont(FONT_NOKIA, nokia);
    #end
  }

  function getFont(demoIndex:Int):String {
    if (demoIndex == 1 || demoIndex == 3) return FONT_LIBERATION;
    if (demoIndex == 4 || demoIndex == 5) return FONT_NOKIA;
    return 'serif';
  }

  function getSize(demoIndex:Int):Int {
    return switch (demoIndex) {
      case 0, 1: 24;
      case 2, 3: 12;
      case 4: 8;
      case 5: 16;
      default: 24;
    }
  }

  function updateComparison():Void {
    if (comparisonRenderer == null) {
      comparison.alpha = 0;
      invalidateNodeRender(comparison);
      return;
    }
    final image = comparisonImages.get(comparisonRenderer + demo);
    comparison.data.texture = image == null ? null : createTexture(cast {dimension: '2d', source: image});
    comparison.alpha = comparisonAlpha;
    invalidateNodeRender(comparison);
  }

  function showDemo(nextDemo:Int):Void {
    demo = nextDemo;
    label.data.text = comparisonRenderer == null ? 'HTML5' : 'HTML5 vs ' + comparisonRenderer;

    final font = getFont(demo);
    final size = getSize(demo);
    for (i in 0...textFields.length) {
      textFields[i].data.defaultTextFormat = {
        align: ALIGNS[i],
        color: 0x000000,
        font: font,
        leading: 20,
        size: size,
      };
      invalidateNodeRender(textFields[i]);
    }

    instructions.data.text = 'Showing demo (' + demo + '). Left/Right: Change demo; 1/2: Compare to '
      + 'Flash/Legacy; Up/Down: Change comparison alphas';
    invalidateNodeRender(instructions);
    updateComparison();
  }

  function cycleAlpha(direction:Int):Void {
    comparisonAlpha = Math.max(0, Math.min(1, comparisonAlpha + direction * 0.25));
    updateComparison();
  }

  override public function onKeyDown(keyCode:KeyCode, modifier:KeyModifier):Void {
    if (!ready) return;
    if (keyCode == KeyCode.LEFT) showDemo(demo > 0 ? demo - 1 : MAX_DEMO);
    else if (keyCode == KeyCode.RIGHT) showDemo(demo < MAX_DEMO ? demo + 1 : 0);
    else if (keyCode == KeyCode.NUMBER_1) {
      comparisonRenderer = 'flash';
      showDemo(demo);
    } else if (keyCode == KeyCode.NUMBER_2) {
      comparisonRenderer = 'legacy';
      showDemo(demo);
    } else if (keyCode == KeyCode.NUMBER_3) {
      comparisonRenderer = 'html5';
      showDemo(demo);
    } else if (keyCode == KeyCode.UP) cycleAlpha(-1);
    else if (keyCode == KeyCode.DOWN) cycleAlpha(1);
  }

  override public function render(context:RenderContext):Void {
    if (!ready || root == null) return;
    if (!drawFrame(root)) window.onRender.cancel();
  }
}
