// Haxe/Lime port of ts/src/glsl-bitmap/app.ts.
//
// GL only — see RenderGl.hx. The fragment source is passed through verbatim; it is GLSL ES 3.00,
// which is what the WebGL2/OpenGL contexts Lime hands out expect.
package;

import LimeCanvas.LimeAssets;
import flighthq.app.App;
import flighthq.hostLime.LimeApp;
import flighthq.sdk.Sdk.*;
import flighthq.types.DisplayObject;
import lime.app.Application;
import lime.graphics.RenderContext;

class Main extends Application {
  static final FRAGMENT_SOURCE = "#version 300 es
precision highp float;
in vec2 v_texCoord;
uniform sampler2D u_texture0;
out vec4 o_color;
void main() {
  o_color = texture(u_texture0, v_texCoord);
}";

  var scale:Float = 1.0;
  var ready = false;

  var root:DisplayObject;
  var effects:Array<Dynamic> = [];

  public function new() {
    super();
  }

  override public function onWindowCreate():Void {
    App.setAppBackend(LimeApp.createLimeAppBackend(this));
    switch (window.context.type) {
      case OPENGL, OPENGLES, WEBGL:
        RenderGl.init(window);
        scale = RenderGl.scale;
      default:
        throw 'glsl-bitmap is a custom fragment shader and needs an OpenGL/WebGL context; got ' + window.context.type;
    }
  }

  override public function onPreloadComplete():Void {
    root = createDisplayObject();
    root.scaleX = scale;
    root.scaleY = scale;

    final logo = createSprite();
    logo.data.texture = createTexture(cast {
      dimension: '2d',
      source: LimeAssets.image('images/openfl_icon_large.png'),
    });
    logo.x = 100;
    logo.y = 100;
    addNodeChild(root, logo);

    RenderGl.registerCustomShader('passthrough', FRAGMENT_SOURCE);
    effects = [createCustomShaderEffect({shaderKey: 'passthrough'})];

    ready = true;
  }

  override public function render(context:RenderContext):Void {
    if (!ready || root == null) return;
    if (!RenderGl.render(root, effects)) window.onRender.cancel();
  }
}
