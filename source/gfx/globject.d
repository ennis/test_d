module gfx.globject;
import opengl;

abstract class GLObject
{
    ~this()
    {
    }

    void release();

    protected GLuint obj;
}
