module gfx.sampler;
import opengl;
import gfx.globject;

class Sampler : GLObject
{
    static struct Desc
    {
        GLenum addrU = GL_REPEAT;
        GLenum addrV = GL_REPEAT;
        GLenum addrW = GL_REPEAT;
        GLenum minFilter = GL_NEAREST;
        GLenum magFilter = GL_NEAREST;

        static immutable(Desc) NearestRepeat = Desc(GL_REPEAT, GL_REPEAT, GL_REPEAT, GL_NEAREST, GL_NEAREST);
        static immutable(Desc) LinearRepeat = Desc(GL_REPEAT, GL_REPEAT, GL_REPEAT, GL_NEAREST, GL_NEAREST);
    }


    this(in Desc desc_)
    {
        desc = desc_;
    }

    override void release()
    {
        if (obj)
            glDeleteSamplers(1, &obj);
    }

    static Sampler get(in Sampler.Desc desc)
    {
        // look in cache
        if(auto ptr = desc in samplerCache) {
            return *ptr;
        }
        auto s = new Sampler(desc);
        samplerCache[desc] = s;
        return s;
    } 

    @property static Sampler nearestRepeat() { return Sampler.get(Desc.NearestRepeat); }
    @property static Sampler linearRepeat() { return Sampler.get(Desc.LinearRepeat); }

    immutable(Desc) desc;
    
    private static Sampler[Sampler.Desc] samplerCache;
}
