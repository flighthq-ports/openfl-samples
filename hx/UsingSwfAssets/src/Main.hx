// Haxe/Lime port of ts/src/using-swf-assets/app.ts.
//
// ts/ fetches the SWF over HTTP and drives layout off createApplicationWindow + attachWindowResize,
// which binds to document.documentElement. Neither exists outside a browser, so the bytes come from
// the bundled asset and the resize hook is Lime's own onWindowResize. Everything the sample is
// actually about — registerDeflateDecompressor, createScene2DSymbolFromSwf, findNodeByName and the
// setNodeWidth/Height layout maths — is unchanged.
package;

import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  var scale:Float = 1.0;
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var layout:DisplayObject;
  var background:Dynamic;
  var column:Dynamic;
  var header:Dynamic;
  var columnOffsetHeight:Float = 0;
  var headerOffsetWidth:Float = 0;

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
    registerDeflateDecompressor();

    final bytes = LimeAssets.bytes('swf/layout.swf');
    final layoutDocument = createScene2DSymbolFromSwf(toUint8Array(bytes), 'Layout');
    if (layoutDocument == null) throw 'Unable to decode the Layout symbol';

    layout = layoutDocument.root;
    background = requireNode('Background');
    column = requireNode('Column');
    header = requireNode('Header');

    columnOffsetHeight = getNodeHeight(column) - getNodeHeight(layout);
    headerOffsetWidth = getNodeWidth(header) - getNodeWidth(layout);
    layout.scaleX = scale;
    layout.scaleY = scale;

    ready = true;
    resize(window.width, window.height);
  }

  function requireNode(name:String):Dynamic {
    final node = findNodeByName(layout, name);
    if (node == null) throw 'Layout symbol is missing ' + name;
    return node;
  }

  // Flight parses the SWF from its own byte view, so the Lime bytes are copied into one.
  static function toUint8Array(bytes:haxe.io.Bytes):flighthq._internal._UInt8Array {
    final out = new flighthq._internal._UInt8Array(bytes.length);
    for (i in 0...bytes.length) out[i] = bytes.get(i);
    return out;
  }

  function resize(width:Float, height:Float):Void {
    if (!ready) return;
    setNodeWidth(background, width);
    setNodeHeight(background, height);
    setNodeHeight(column, Math.max(height + columnOffsetHeight, 0));
    setNodeWidth(header, Math.max(width + headerOffsetWidth, 0));
  }

  // ts/ uses createApplicationWindow + attachWindowResize(win, document.documentElement); Lime
  // reports the same event on the Application itself.
  override public function onWindowResize(width:Int, height:Int):Void {
    resize(width, height);
  }

  override public function render(context:RenderContext):Void {
    if (!ready || layout == null) return;
    if (!drawFrame(layout)) window.onRender.cancel();
  }
}
