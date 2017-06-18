module engine.render_utils;

import core.cache;
import core.types;
import core.transform;
import core.camera;
import core.vertex;
import gfx.texture;
import gfx.buffer;
import gfx.draw;
import gfx.bind;
import gfx.sampler;
import gfx.frame;
import gfx.framebuffer;
import engine.mesh;
import engine.pipeline;
import engine.globals;
 
private class State 
{
    this(Cache cache = getDefaultCache()) 
    {
        reloadShaders(cache);
    }

    void reloadShaders(Cache cache) {
        drawMeshShader = new GraphicsPipeline(cache, "data/shaders/default.lua$drawMeshDefault");
        drawSpriteShader = new GraphicsPipeline(cache, "data/shaders/default.lua$drawSprite");
        drawWireMeshShader = new GraphicsPipeline(cache, "data/shaders/default.lua$drawWireMesh");
        drawWireMeshNoDepthShader = new GraphicsPipeline(cache, "data/shaders/default.lua$drawWireMeshNoDepth");
        drawWireMesh2DColorShader = new GraphicsPipeline(cache, "data/shaders/default.lua$drawWireMesh2DColor");
    }

    Sampler samplerNearest;
    Sampler samplerLinear;
    GraphicsPipeline drawSpriteShader;
    GraphicsPipeline drawMeshShader;
    GraphicsPipeline drawWireMeshShader;
    GraphicsPipeline drawWireMeshNoDepthShader;
    GraphicsPipeline drawWireMesh2DColorShader;
}

private auto getState()
{
    import std.concurrency : initOnce;
    static __gshared State renderUtilsState;
    initOnce!(renderUtilsState)(new State());
    return renderUtilsState;
}

// Draw mesh with default view-dependent shading
void drawMesh(Framebuffer target, ref const(Camera) cam, ref Mesh3D mesh, vec3 pos,
              float scale, vec4 color) 
{
    Transform t;
    t.position = pos;
    t.scaling = vec3(scale);
    auto mat = t.matrix;
    drawMesh(target, cam, mesh, mat, color);
}

// Structs follow the same layout rules as C structs
private struct CameraUniforms 
{
    this(ref const(Camera) cam)
    {
        viewMatrix = cam.viewMatrix.transposed;
        projMatrix = cam.projMatrix.transposed;
        viewProjMatrix = (cam.projMatrix * cam.viewMatrix).transposed;
        invProjMatrix = cam.projMatrix.inverse.transposed;
    }

    mat4 viewMatrix;
    mat4 projMatrix;
    mat4 viewProjMatrix;
    mat4 invProjMatrix;
}

void drawMesh(Framebuffer target, ref const(Camera) cam, ref Mesh3D mesh,
              mat4 modelTransform, vec4 color) 
{
  auto camUniforms = CameraUniforms(cam);
  auto state = getState();

  draw(target, mesh, state.drawMeshShader,
       UniformBuffer(0, uploadFrameData(camUniforms)),
       UniformMat4("uModelMatrix", modelTransform),
       UniformVec4("uColor", color));

	//drawQuad(target, state.drawSpriteShader, UniformVec4("uColor", color));
}

void drawWireMesh(Framebuffer target, ref const(Camera) cam, ref Mesh3D mesh,
              mat4 modelTransform, vec4 color) 
{
  auto camUniforms = CameraUniforms(cam);
  auto state = getState();

  draw(target, mesh, state.drawWireMeshNoDepthShader,
       UniformBuffer(0, uploadFrameData(camUniforms)),
       UniformMat4("uModelMatrix", modelTransform),
       UniformVec4("uColor", color));

	//drawQuad(target, state.drawSpriteShader, UniformVec4("uColor", color));
}

void drawLines(Framebuffer target, ref const(Camera) cam,
               const(Vertex3D)[] lines, mat4 modelTransform, float lineWidth,
               vec4 wireColor) 
{
  auto camUniforms = CameraUniforms(cam);
  auto vbuf = uploadFrameData(lines);
  auto state = getState();

  // gl::LineWidth(lineWidth);
  /*draw(target, DrawArrays(GL_LINES, 0, (uint32_t)lines.size()),
       state.drawWireMeshNoDepthShader, bind::uniformFrameData(0, &camUniforms),
       bind::uniform_mat4("uModelMatrix", modelTransform),
       bind::uniform_vec4("uWireColor", wireColor),
       bind::vertexBuffer(0, vbuf, sizeof(Vertex3D)));*/
}