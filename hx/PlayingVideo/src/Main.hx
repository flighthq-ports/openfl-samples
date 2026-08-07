// Haxe/Lime port of ts/src/playing-video/app.ts.
//
// Wired against the Flight video API as-is: loadVideoResourceFromUrl / createVideoTexture /
// playVideoResource / advanceVideoTexture. Those are backed by an HTML <video> element in the
// generated port, which has no counterpart outside a browser and no Lime host in flight-hx, so this
// is expected to fail on neko — deliberately left unstubbed so the gap is visible.
package;

import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Shape;
import flighthq.types.Sprite;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.MouseButton;

class Main extends Application {
  static inline final WIDTH = 800;
  static inline final HEIGHT = 600;

  var scale:Float = 1.0;
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var tweenManager:Dynamic;
  var root:DisplayObject;
  var videoSource:Dynamic;
  var videoTexture:Dynamic;
  var videoNode:Sprite;
  var overlay:Shape;
  var channel:Dynamic = null;
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
    tweenManager = createTweenManager({defaultEase: easeOutQuadratic});
    root = createDisplayObject();
    root.scaleX = scale;
    root.scaleY = scale;

    loadVideoResourceFromUrl('videos/example.mp4').then(function(resource:Dynamic) {
      videoSource = resource;
      videoTexture = createVideoTexture(videoSource);
      videoNode = createSprite();
      videoNode.data.texture = videoTexture;
      addNodeChild(root, videoNode);

      overlay = createShape();
      addNodeChild(root, overlay);

      resize(WIDTH, HEIGHT);
      ready = true;
      return null;
    }, function(_:Dynamic) return null);

    app = createApplication();
    connectSignal(app.onUpdate, function(delta:Float) updateTweens(tweenManager, delta));
  }

  function play():Void {
    if (channel != null) stopVideoChannel(channel);
    channel = playVideoResource(videoSource);
    if (channel == null) return;
    overlay.alpha = 1;
    overlay.visible = true;
    invalidateNodeRender(overlay);

    final fade = createTween(tweenManager, overlay, 2000, {alpha: 0});
    connectSignal(fade.onUpdate, function() invalidateNodeRender(overlay));
    connectSignal(fade.onComplete, function() {
      overlay.visible = false;
      invalidateNodeRender(overlay);
    });

    final started = channel;
    connectSignal(started.onComplete, function() {
      channel = null;
      overlay.visible = true;
      final fadeIn = createTween(tweenManager, overlay, 1000, {alpha: 1});
      connectSignal(fadeIn.onUpdate, function() invalidateNodeRender(overlay));
    });
  }

  function resize(w:Float, h:Float):Void {
    videoNode.x = 0;
    videoNode.y = 0;
    videoNode.scaleX = 1;
    videoNode.scaleY = 1;
    clearShapeCommands(overlay);
    appendShapeBeginFill(overlay, 0x000000, 0.5);
    appendShapeRectangle(overlay, 0, 0, 560, 320);
    invalidateNodeRender(videoNode);
    invalidateNodeRender(overlay);
  }

  override public function onWindowResize(width:Int, height:Int):Void {
    if (ready) resize(width, height);
  }

  override public function onMouseDown(x:Float, y:Float, button:MouseButton):Void {
    if (ready) play();
  }

  override public function update(deltaTime:Int):Void {
    if (app == null) return;
    if (ready && videoTexture != null) advanceVideoTexture(videoTexture);
    stepApplicationLoop(app, deltaTime);
  }

  override public function render(context:RenderContext):Void {
    if (!ready || root == null) return;
    if (!drawFrame(root)) window.onRender.cancel();
  }
}
