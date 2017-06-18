module gfx.bind;
import opengl;
import gfx.state_group;
import gfx.texture;
import gfx.sampler;
import gfx.buffer;
import gfx.upload_buffer;
import gfx.framebuffer;
import gfx.context;
import core.types;

enum isPipelineBindable(T) = is(typeof(() {
            T t;
            StateGroup sg;
            t.bind(sg); // can bind to a state group
        }()));

struct Uniform(T)
{
    string name;
    T value;

    void bind(ref StateGroup sg)
    {
        import std.string : toStringz;
        import std.conv : to;

        int loc = glGetUniformLocation(sg.program, name.ptr);
        static if (is(T == float))
        {
            glProgramUniform1f(sg.program, toStringz(name), value);
        }
        static if (is(T == int))
        {
            glProgramUniform1i(sg.program, toStringz(name), value);
        }
        static if (is(T == Vector!(U, N), U=float, int N))
        {
            mixin("glProgramUniform" ~ to!string(N) ~ "fv(sg.program, loc, 1, value.ptr);");
        }
        static if (is(T == Vector!(U, N), U=int, int N))
        {
            mixin("glProgramUniform" ~ to!string(N) ~ "iv(sg.program, loc, 1, value.ptr);");
        }
        static if (is(T == Matrix!(float, R, C), int R, int C))
        {
            static assert(R >= 2 && C >= 2 && R <= 4 && C <= 4);
            static if (R == C)
            {
                mixin("glProgramUniformMatrix" ~ to!string(
                        R) ~ "fv(sg.program, loc, 1, true, value.ptr);");
            }
            else
            {
                mixin("glProgramUniformMatrix" ~ to!string(C) ~ "x" ~ to!string(
                        R) ~ "fv(sg.program, loc, 1, true, value.ptr);");
            }
        }
    }
}

alias UniformVec2 = Uniform!(vec2);
alias UniformVec3 = Uniform!(vec3);
alias UniformVec4 = Uniform!(vec4);
alias UniformIVec2 = Uniform!(ivec2);
alias UniformIVec3 = Uniform!(ivec3);
alias UniformIVec4 = Uniform!(ivec4);
alias UniformMat2 = Uniform!(mat2);
alias UniformMat3 = Uniform!(mat3);
alias UniformMat4 = Uniform!(mat4);

struct TextureUnit
{
    int unit;
    Texture tex;
    Sampler sampler;

    void bind(ref StateGroup sg)
    {
        sg.uniforms.textures[unit] = tex.object;
        sg.uniforms.samplers[unit] = sampler.object;
    }
}

struct ImageUnit
{
    int unit;
    Texture tex;

    void bind(ref StateGroup sg)
    {
        sg.uniforms.images[unit] = tex.object;
    }
}

struct UniformBuffer
{
    int slot;
    Buffer.Slice slice;

    void bind(ref StateGroup sg) const
    {
        sg.uniforms.uniformBuffers[slot] = slice.obj;
        sg.uniforms.uniformBufferOffsets[slot] = slice.offset;
        sg.uniforms.uniformBufferSizes[slot] = slice.size;
    }
}

struct VertexBuffer
{
    int slot;
    Buffer.Slice buffer;
    int stride;

    void bind(ref StateGroup sg) const
    {
        sg.uniforms.vertexBuffers[slot] = buffer.obj;
        sg.uniforms.vertexBufferOffsets[slot] = buffer.offset;
        sg.uniforms.vertexBufferStrides[slot] = cast(GLsizei) stride;
    }
}

struct IndexBuffer
{
    Buffer.Slice buffer;
    GLenum type;

    void bind(ref StateGroup sg) const
    {
        sg.uniforms.indexBuffer = buffer;
        sg.uniforms.indexBufferType = type;
    }
}

struct RenderTarget
{
    Framebuffer fbo;

    void bind(ref StateGroup sg) const
    {
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fbo.object);
        sg.viewports[0] = Viewport(0.0f, 0.0f, cast(float) fbo.width, cast(float) fbo.height);
        sg.scissorRects[0] = ScissorRect(0, 0, fbo.width, fbo.height);
    }
}


unittest
{
    static assert(isPipelineBindable!TextureUnit);
    static assert(isPipelineBindable!ImageUnit);
    static assert(isPipelineBindable!UniformBuffer);
    static assert(isPipelineBindable!UniformVec2);
    static assert(isPipelineBindable!UniformVec3);
    static assert(isPipelineBindable!UniformVec4);
    static assert(isPipelineBindable!VertexBuffer);
    static assert(isPipelineBindable!IndexBuffer);
}
