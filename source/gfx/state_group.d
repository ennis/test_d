module gfx.state_group;
import opengl;
import gfx.buffer;

//////////////////////////////////////////////////
enum StateGroupMask
{
    Viewports = (1 << 0), // DONE
    Framebuffer = (1 << 1), // DONE
    ScissorRect = (1 << 2),
    BlendStates = (1 << 3), // DONE
    RasterizerState = (1 << 4), // DONE
    DepthStencilState = (1 << 5), // DONE
    Textures = (1 << 6), // DONE
    Samplers = (1 << 7),
    UniformBuffers = (1 << 8), // DONE
    ShaderStorageBuffers = (1 << 9), // DONE
    VertexArray = (1 << 10), // DONE
    Program = (1 << 11), // DONE
    VertexBuffers = (1 << 12), // DONE
    IndexBuffer = (1 << 13), // DONE
    Images = (1 << 14), // DONE
    AllCompute = Images | Textures | Samplers | Program | UniformBuffers | ShaderStorageBuffers,
    All = 0xFFFFFFF
}

struct BlendState
{
    bool enabled = true;
    GLenum modeRGB = GL_FUNC_ADD;
    GLenum modeAlpha = GL_FUNC_ADD;
    GLenum funcSrcRGB = GL_SRC_ALPHA;
    GLenum funcDstRGB = GL_ONE_MINUS_SRC_ALPHA;
    GLenum funcSrcAlpha = GL_ONE;
    GLenum funcDstAlpha = GL_ZERO;
}

struct DepthStencilState
{
    bool depthTestEnable = false;
    bool depthWriteEnable = false;
    bool stencilEnable = false;
    GLenum depthTestFunc = GL_LEQUAL;
    GLenum stencilFace = GL_FRONT_AND_BACK;
    GLenum stencilFunc = 0;
    GLint stencilRef = 0;
    GLuint stencilMask = 0xFFFFFFFF;
    GLenum stencilOpSfail = 0;
    GLenum stencilOpDPFail = 0;
    GLenum stencilOpDPPass = 0;
}

struct RasterizerState
{
    GLenum fillMode = GL_FILL;
    GLenum cullMode = GL_NONE;
    GLenum frontFace = GL_CCW;
    float depthBias = 1.0f;
    float slopeScaledDepthBias = 1.0f;
    bool depthClipEnable = false;
    bool scissorEnable = false;
}

struct ScissorRect
{
    int x;
    int y;
    int w;
    int h;
}

struct Viewport
{
    float x;
    float y;
    float w;
    float h;
}

struct Uniforms
{
    enum int MaxTextureUnits = 16;
    enum int MaxImageUnits = 8;
    enum int MaxVertexBufferSlots = 8;
    enum int MaxUniformBufferSlots = 8;
    enum int MaxShaderStorageBufferSlots = 8;

    GLuint[MaxTextureUnits] textures;
    GLuint[MaxTextureUnits] samplers;
    GLuint[MaxImageUnits] images;
    GLuint[MaxUniformBufferSlots] uniformBuffers;
    GLsizeiptr[MaxUniformBufferSlots] uniformBufferSizes;
    GLintptr[MaxUniformBufferSlots] uniformBufferOffsets;
    GLuint[MaxShaderStorageBufferSlots] shaderStorageBuffers;
    GLsizeiptr[MaxShaderStorageBufferSlots] shaderStorageBufferSizes;
    GLintptr[MaxShaderStorageBufferSlots] shaderStorageBufferOffsets;
    GLuint[MaxVertexBufferSlots] vertexBuffers;
    GLintptr[MaxVertexBufferSlots] vertexBufferOffsets;
    GLsizei[MaxVertexBufferSlots] vertexBufferStrides;
    Buffer.Slice indexBuffer;
    GLenum indexBufferType;
}

struct StateGroup
{
    StateGroupMask mask;
    DepthStencilState depthStencilState;
    RasterizerState rasterizerState;
    BlendState[8] blendStates;
    ScissorRect[8] scissorRects;
    Viewport[8] viewports;
    GLuint vertexArray;
    GLuint program;
    Uniforms uniforms;
    GLbitfield barrierBits;
};

void bindStateGroup(ref const(StateGroup) sg)
{
    // Viewports
    if (sg.mask & StateGroupMask.Viewports)
    {
        glViewportArrayv(0, 8, cast(const float*) sg.viewports.ptr);
    }

    // Scissor rect
    if (sg.mask & StateGroupMask.ScissorRect)
    {
        glScissorArrayv(0, 8, cast(const int*) sg.scissorRects.ptr);
    }

    // Blend states
    if (sg.mask & StateGroupMask.BlendStates)
    {
        if (!sg.blendStates.length)
            glDisable(GL_BLEND);
        else
        {
            glEnable(GL_BLEND); // XXX is this necessary
            for (int i = 0; i < 8; ++i)
            {
                if (sg.blendStates[i].enabled)
                {
                    glEnablei(GL_BLEND, i);
                    glBlendEquationSeparatei(i, sg.blendStates[i].modeRGB,
                            sg.blendStates[i].modeAlpha);
                    glBlendFuncSeparatei(i, sg.blendStates[i].funcSrcRGB,
                            sg.blendStates[i].funcDstRGB, sg.blendStates[i].funcSrcAlpha,
                            sg.blendStates[i].funcDstAlpha);
                }
                else
                    glDisablei(GL_BLEND, i);
            }
        }
    }

    // Depth stencil state
    if (sg.mask & StateGroupMask.DepthStencilState)
    {
        if (sg.depthStencilState.depthTestEnable)
            glEnable(GL_DEPTH_TEST);
        else
            glDisable(GL_DEPTH_TEST);

        if (sg.depthStencilState.depthWriteEnable)
            glDepthMask(GL_TRUE);
        else
            glDepthMask(GL_FALSE);

        glDepthFunc(sg.depthStencilState.depthTestFunc);

        if (sg.depthStencilState.stencilEnable)
        {
            glEnable(GL_STENCIL_TEST);
            glStencilFuncSeparate(sg.depthStencilState.stencilFace, sg.depthStencilState.stencilFunc,
                    sg.depthStencilState.stencilRef, sg.depthStencilState.stencilMask);
            glStencilOp(sg.depthStencilState.stencilOpSfail,
                    sg.depthStencilState.stencilOpDPFail, sg.depthStencilState.stencilOpDPPass);
        }
        else
            glDisable(GL_STENCIL_TEST);
    }

    // Rasterizer
    if (sg.mask & StateGroupMask.RasterizerState)
    {
        glPolygonMode(GL_FRONT_AND_BACK, sg.rasterizerState.fillMode);
        glDisable(GL_CULL_FACE);
    }

    // Vertex array
    if (sg.mask & StateGroupMask.VertexArray)
    {
        glBindVertexArray(sg.vertexArray);
    }

    // program
    if (sg.mask & StateGroupMask.Program)
    {
        glUseProgram(sg.program);
    }

    // Uniforms
    bindUniforms(sg.uniforms);

}

private void bindUniforms(ref const(Uniforms) uniforms)
{
    // VBOs
    for (int i = 0; i < Uniforms.MaxVertexBufferSlots; ++i)
        if (uniforms.vertexBuffers[i])
            glBindVertexBuffer(i, uniforms.vertexBuffers[i],
                    uniforms.vertexBufferOffsets[i], uniforms.vertexBufferStrides[i]);
        else
            glBindVertexBuffer(i, 0, 0, 0);
    // IBO
    if (uniforms.indexBuffer.obj)
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, uniforms.indexBuffer.obj);
    // Textures
    glBindTextures(0, Uniforms.MaxTextureUnits, uniforms.textures.ptr);
    // Samplers
    glBindSamplers(0, Uniforms.MaxTextureUnits, uniforms.samplers.ptr);
    // Images
    glBindImageTextures(0, Uniforms.MaxImageUnits, uniforms.images.ptr);
    // UBOs
    for (int i = 0; i < Uniforms.MaxUniformBufferSlots; ++i)
    {
        if (uniforms.uniformBuffers[i])
            glBindBufferRange(GL_UNIFORM_BUFFER, i, uniforms.uniformBuffers[i],
                    uniforms.uniformBufferOffsets[i], uniforms.uniformBufferSizes[i]);
        else
            glBindBufferBase(GL_UNIFORM_BUFFER, i, 0);
    }
    // SSBOs
    for (int i = 0; i < Uniforms.MaxUniformBufferSlots; ++i)
    {
        if (uniforms.uniformBuffers[i])
            glBindBufferRange(GL_SHADER_STORAGE_BUFFER, i, uniforms.shaderStorageBuffers[i],
                    uniforms.shaderStorageBufferOffsets[i], uniforms.shaderStorageBufferSizes[i]);
        else
            glBindBufferBase(GL_SHADER_STORAGE_BUFFER, i, 0);
    }
}
