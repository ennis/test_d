module gfx.globject;
import opengl;

abstract class GLObject
{
    ~this()
    {
        release();
    }

    @property auto object() const { return obj; }

    abstract void release() @nogc;

    protected GLuint obj;
}
