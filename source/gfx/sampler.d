module gfx.sampler;
import opengl;
import gfx.globject;

class Sampler : GLObject
{
    struct Desc
    {
        string s;
        GLenum addrU = GL_REPEAT;
        GLenum addrV = GL_REPEAT;
        GLenum addrW = GL_REPEAT;
        GLenum minFilter = GL_NEAREST;
        GLenum magFilter = GL_NEAREST;
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

    immutable(Desc) desc;
}
