module gfx.bind;
import opengl;
import gfx.state_group;
import gfx.texture;
import gfx.sampler;
import gfx.buffer;
import gfx.upload_buffer;
import core.types;

enum isPipelineBindable(T) = is(typeof(
    () {
        T t;
        StateGroup sg;
        t.bind(sg); // can bind to a state group
    }()
));


struct Uniform(T)
{
    string name;
    T value;

    void bind(ref StateGroup sg) 
    {
    }
}

alias UniformVec2 = Uniform!(vec2);
alias UniformVec3 = Uniform!(vec3);
alias UniformVec4 = Uniform!(vec4);


struct TextureUnit {
    int unit;
    Texture tex;
    Sampler sampler;

    void bind(ref StateGroup sg) {
        sg.uniforms.textures[unit] = tex.object;
        sg.uniforms.samplers[unit] = sampler.object;
    }
}

struct ImageUnit {
    int unit;
    Texture tex;

    void bind(ref StateGroup sg) {
        sg.uniforms.images[unit] = tex.object;
    }
}

struct UniformBuffer {
    int slot;
    Buffer.Slice slice;

    void bind(ref StateGroup sg) {
        sg.uniforms.uniformBuffers[slot] = slice.obj;
    }
}

unittest {
 static assert(isPipelineBindable!TextureUnit);
 static assert(isPipelineBindable!ImageUnit);
 static assert(isPipelineBindable!UniformBuffer);
 static assert(isPipelineBindable!UniformVec2);
 static assert(isPipelineBindable!UniformVec3);
 static assert(isPipelineBindable!UniformVec4);
}

