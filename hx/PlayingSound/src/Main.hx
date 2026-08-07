// Haxe/Lime port of ts/src/playing-sound/app.ts.
//
// Wired against the Flight audio API as-is: loadAudioResourceFromUrls / playAudioResource /
// setAudioChannelGain / stopAudioChannel, with an AudioContext from the JS global the way ts/ does it.
// That context has no counterpart outside a browser, and flight-hx ships no Lime audio host, so this
// is expected to fail on neko — deliberately left unstubbed so the gap is visible rather than papered
// over.
package;

import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import flighthq.types.Shape;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.ui.MouseButton;

class Main extends Application {
  static inline final WIDTH = 800;
  static inline final HEIGHT = 600;

  var scale:Float = 1.0;
  var drawFrame:DisplayObject->Bool;
  var ready = false;

  var manager:Dynamic;
  var root:DisplayObject;
  var background:Shape;
  var app:Dynamic;

  var audioContext:Dynamic = null;
  var sound:Dynamic = null;
  var channel:Dynamic = null;
  var playing = false;
  var position:Float = 0;

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

    manager = createTweenManager({defaultEase: easeOutQuadratic});
    root = createDisplayObject();
    root.scaleX = scale;
    root.scaleY = scale;

    background = createShape();
    background.alpha = 0.1;
    addNodeChild(root, background);
    resize(WIDTH, HEIGHT);

    app = createApplication();
    connectSignal(app.onUpdate, function(delta:Float) updateTweens(manager, delta));

    ready = true;
  }

  override public function onPreloadComplete():Void {
    loadAudioResourceFromUrls(ensureAudioContext(), [{url: 'sounds/stars.ogg'}]).then(function(resource:Dynamic) {
      sound = resource;
      return null;
    }, function(_:Dynamic) return null);
  }

  // ts/ constructs `new AudioContext()`; the generated port reaches the same global.
  function ensureAudioContext():Dynamic {
    if (audioContext == null) {
      audioContext = flighthq._internal._Runtime.construct(flighthq._internal._Runtime.globalValue('AudioContext'), []);
    }
    return audioContext;
  }

  function pause(fadeOut:Float = 1200):Void {
    if (!playing || channel == null) return;
    playing = false;
    final fadingChannel = channel;

    final audioTween = createTween(manager, fadingChannel, fadeOut, {gain: 0});
    connectSignal(audioTween.onUpdate, function() setAudioChannelGain(fadingChannel, fadingChannel.gain));
    connectSignal(audioTween.onComplete, function() {
      position = fadingChannel.currentTime;
      stopAudioChannel(fadingChannel);
      if (channel == fadingChannel) channel = null;
    });

    final backgroundTween = createTween(manager, background, fadeOut, {alpha: 0.1});
    connectSignal(backgroundTween.onUpdate, function() invalidateNodeRender(background));
  }

  function play(fadeIn:Float = 3000):Void {
    if (sound == null) return;

    if (channel != null) {
      stopAudioChannel(channel);
      channel = null;
    }

    final nextChannel = playAudioResource(ensureAudioContext(), sound, {
      currentTime: position,
      gain: fadeIn <= 0 ? 1 : 0,
    });
    if (nextChannel == null) return;

    channel = nextChannel;
    playing = true;

    connectSignal(nextChannel.onComplete, function() {
      playing = false;
      position = 0;
      if (channel == nextChannel) channel = null;
      background.alpha = 0.1;
      invalidateNodeRender(background);
    });

    if (fadeIn > 0) {
      final audioTween = createTween(manager, nextChannel, fadeIn, {gain: 1});
      connectSignal(audioTween.onUpdate, function() setAudioChannelGain(nextChannel, nextChannel.gain));
    }

    final backgroundTween = createTween(manager, background, fadeIn, {alpha: 1});
    connectSignal(backgroundTween.onUpdate, function() invalidateNodeRender(background));
  }

  function resize(w:Float, h:Float):Void {
    clearShapeCommands(background);
    appendShapeBeginFill(background, 0x24afc4);
    appendShapeRectangle(background, 0, 0, w, h);
    invalidateNodeRender(background);
  }

  override public function onWindowResize(width:Int, height:Int):Void {
    if (ready) resize(width, height);
  }

  override public function onMouseDown(x:Float, y:Float, button:MouseButton):Void {
    if (!ready) return;
    if (playing) pause() else play();
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
