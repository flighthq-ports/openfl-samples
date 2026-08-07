// Haxe/Lime port of ts/src/nyan-cat/app.ts.
//
// ts/ fetches the SWF over HTTP; the bytes come from the bundled asset here. The rest — the deflate
// decompressor, createScene2DFromSwf, and driving the MovieClip from the frame delta — is unchanged.
package;

import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.MovieClip;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  static inline final STAGE_W = 600;
  static inline final STAGE_H = 600;

  var scale:Float = 1.0;
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var root:DisplayObject;
  var clip:MovieClip;
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
    registerDeflateDecompressor();

    final bytes = LimeAssets.bytes('swf/library.swf');
    final document = createScene2DFromSwf(toUint8Array(bytes));
    if (document == null) throw 'Unable to decode the Nyan Cat SWF';

    root = document.root;
    final children = getNodeChildren(root);
    final clipNode = children.length > 0 ? children[0] : null;
    if (clipNode == null || clipNode.kind != MovieClipKind) throw 'Nyan Cat SWF is missing its animated clip';

    clip = cast clipNode;
    root.x = (STAGE_W - getNodeWidth(root)) / 2;
    root.y = (STAGE_H - getNodeHeight(root)) / 2;
    root.scaleX = scale;
    root.scaleY = scale;
    invalidateNodeLocalTransform(root);
    playMovieClip(clip);

    app = createApplication();
    connectSignal(app.onUpdate, function(delta:Float) updateMovieClip(clip, delta));

    ready = true;
  }

  static function toUint8Array(bytes:haxe.io.Bytes):flighthq._internal._UInt8Array {
    final out = new flighthq._internal._UInt8Array(bytes.length);
    for (i in 0...bytes.length) out[i] = bytes.get(i);
    return out;
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
