module gfx.buffer;
import gfx.globject;
import opengl;

class Buffer : GLObject
{
    static struct Slice
    {
        GLuint obj;
        size_t offset;
        size_t size;
    }

    enum Usage
    {
        Upload, // CPU-visible, write-only
        Default, // GPU-visible, cannot be accessed by the CPU
        Readback // CPU-visible, read-only
    }

    this()
    {
    }

    override void release() 
    {
        if (obj)
            glDeleteBuffers(1, &obj);
    }

    this(Usage usage_, size_t size_, const(void)* initialData = null)
    {
        usage = usage_;
        size = size_;

        GLbitfield flags = 0;
        if (usage == Usage.Readback)
        {
            flags |= GL_MAP_READ_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        }
        else if (usage == Usage.Upload)
        {
            flags |= GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        }
        else
        {
            flags = 0;
        }

        glCreateBuffers(1, &obj);
        glNamedBufferStorage(obj, size, initialData, flags);
    }

    void* map(size_t offset, size_t size)
    {
        GLbitfield flags = GL_MAP_UNSYNCHRONIZED_BIT;
        if (usage == Usage.Readback)
        {
            flags |= GL_MAP_READ_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        }
        else if (usage == Usage.Upload)
        {
            flags |= GL_MAP_WRITE_BIT | GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT;
        }
        else
        {
            // cannot map a DEFAULT buffer
            assert(false, "Trying to map a buffer allocated with Buffer.Usage.Default");
        }
        return glMapNamedBufferRange(obj, offset, size, flags);
    }

    Slice asSlice() const
    {
        return Slice(obj, 0, size);
    }

    immutable(Usage) usage = Usage.Default;
    immutable(size_t) size = 0;
}
