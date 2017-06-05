module gfx.bind;
import opengl;
import gfx.state_group;
import gfx.texture;
import gfx.sampler;
import gfx.buffer;
import gfx.upload_buffer;

enum isPipelineBindable(T) = is(typeof(
    () {
        T t;
        StateGroup sg;
        t.bind(sg); // can bind to a state group
    }
));


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
        
    }
}

unittest {
 static assert(isPipelineBindable!TextureUnit);
 static assert(isPipelineBindable!ImageUnit);
 static assert(isPipelineBindable!UniformBuffer);
}

