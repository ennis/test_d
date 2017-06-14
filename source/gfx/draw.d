module gfx.draw;
import core.types;
import gfx.bind;
import gfx.framebuffer;
import gfx.state_group;
import gfx.texture;
import gfx.context;
import opengl;

struct DrawArrays {
    GLenum primitiveType;
    int first;
    int count;

    void bind(ref StateGroup sg) const
    {
        bindStateGroup(sg);
        glDrawArrays(primitiveType, first, count);
    }
}

struct DrawIndexed {
    GLenum primitiveType;
    int first;
    int count;
    int baseVertex;

    void bind(ref StateGroup sg) const
    {
        bindStateGroup(sg);
        auto indexStride = (sg.uniforms.indexBufferType == GL_UNSIGNED_SHORT) ? 2 : 4;
        glDrawElementsBaseVertex(primitiveType, count, sg.uniforms.indexBufferType,
                             cast(const(char)*) (cast(size_t)first * indexStride),
                             baseVertex);
    }
}

void draw(DrawCommand, Pipeline, Args...)(Framebuffer fbo, DrawCommand cmd, Pipeline pipeline, Args args)
{
    StateGroup sg;
    // 1. bind program & draw states (~= pipeline state)
    shader.bind(sg);
    // 1.1. bind framebuffer
    RenderTarget(fbo).bind(sg);
    // 2. bind dynamic args
    sg.mask = StateGroupMask.All;
    foreach (ref a; args) {
        a.bind(sg);
    }
    // 3. call render command
    // The render command is in charge of binding the state group to the pipeline
    cmd.bind(sg);
}

void clear(Framebuffer fb, vec4 color) {
  glClearNamedFramebufferfv(fb.object, GL_COLOR, 0, &color[0]);
}

void clearTexture(Texture tex, vec4 color) {
  glClearTexImage(tex.object, 0, GL_RGBA, GL_FLOAT, &color[0]);
}

void clearDepth(Framebuffer fb, float depth) {
  glClearNamedFramebufferfv(fb.object, GL_DEPTH, 0, &depth);
}

void clearDepthTexture(Texture tex, float depth) {
  glClearTexImage(tex.object, 0, GL_DEPTH_COMPONENT, GL_FLOAT, &depth);
}

void clearTexture(Texture tex, ivec4 color) {
  glClearTexImage(tex.object, 0, GL_RGBA_INTEGER, GL_INT, &color[0]);
}

void clearTexture(Texture tex, uvec4 color) {
  glClearTexImage(tex.object, 0, GL_RGBA_INTEGER, GL_UNSIGNED_INT, &color[0]);
}


// Helper: draw a screen-aligned quad
void drawQuad(Shader, Args...)(Framebuffer fbo, Shader shader, Args args) {
  struct Vertex2D {
    float x;
    float y;
    float tx;
    float ty;
  }

  immutable(Vertex2D[6]) quad = [
      {-1.0f, -1.0f, 0.0f, 0.0f}, {1.0f, -1.0f, 0.0f, 0.0f},
      {-1.0f, 1.0f, 0.0f, 0.0f},  {-1.0f, 1.0f, 0.0f, 0.0f},
      {1.0f, -1.0f, 0.0f, 0.0f},  {1.0f, 1.0f, 0.0f, 0.0f}];

  // upload vertex data each frame (who cares)
  auto vbuf = uploadFrameArray(quad);

  draw(fbo, DrawArrays(GL_TRIANGLES, 0, 6), shader,
       VertexBuffer(0, vbuf, Vertex2D.sizeof),
       args);
}
