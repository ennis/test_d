module gfx.context;
import core.types;
import core.dbg;
import opengl;

private
{
    extern(System) void debugCallback(GLenum source, GLenum type, GLuint id, GLenum severity,
            GLsizei length, const(GLubyte)* msg, void* data)
    {
        import std.conv : to;
        if (severity != GL_DEBUG_SEVERITY_LOW && severity != GL_DEBUG_SEVERITY_NOTIFICATION)
        {
            import core.runtime : defaultTraceHandler;
            debugMessage("GL: %s", to!string(cast(const(char)*)msg));
            debugMessage("GL: stack trace:");
            debugMessage(defaultTraceHandler.toString());
        }
    }

    void setDebugCallback()
    {
        glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
        glDebugMessageCallback(cast(GLDEBUGPROC)&debugCallback, null);
        glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, null, true);
        glDebugMessageInsert(GL_DEBUG_SOURCE_APPLICATION, GL_DEBUG_TYPE_MARKER, 1111,
                GL_DEBUG_SEVERITY_NOTIFICATION, -1, "Started logging OpenGL messages");
    }
}

struct GLImplementationLimits
{
    int max_vertex_attributes = 16;
    int max_vertex_buffers = 16;
    int max_texture_units = 16;
    int max_draw_buffers = 16;
    int max_3d_texture_size_w;
    int max_3d_texture_size_h;
    int max_3d_texture_size_d;
    int max_combined_texture_image_units = 16;
    int max_combined_uniform_blocks = 16;
    int max_combined_shader_storage_blocks = 16;
    int max_compute_texture_image_units = 16;
    int max_compute_uniform_blocks = 16;
    int max_compute_shader_storage_blocks = 16;
    int max_compute_work_group_invocations;
    int max_compute_work_group_count;
    int max_compute_work_group_size;
    int uniform_buffer_alignment = 256;
    int default_compute_local_size_x;
    int default_compute_local_size_y;
    int default_compute_local_size_z;
}

class Context
{
public:
    struct Config
    {
        int maxFramesInFlight = 0;
        int defaultUploadBufferSize = 0;
    }

    this(Config cfg_)
    {
        cfg = cfg_;
        setDebugCallback();
        //frameFence = Fence{0};
        // TODO query all implementation limits
        glGetIntegerv(GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT, &implLimits.uniform_buffer_alignment);
        // automatically set this instance as the current graphics context
        // this is relatively safe since the GfxContext object cannot be moved 
        // (the copy and move constructors have been disabled)
        //setGfxContext(this);
        if (currentCtx) {
            assert(false, "Global GFX context already set");
        }
        currentCtx = this;
    }

    ~this()
    {
    }

    void setFrameCapture(long targetFrameIndex)
    {
        nextFrameCapture = targetFrameIndex;
    }

    void setNextFrameCapture()
    {
        nextFrameCapture = currentFrameIndex + 1;
    }

    bool isFrameCaptureRequested()
    {
        return nextFrameCapture == currentFrameIndex;
    }

    // disable copy and move
    @property ref const(GLImplementationLimits) implementationLimits()
    {
        return implLimits;
    }

    void resizeRenderWindow(int w, int h)
    {
        width = w;
        height = h;
    }

    @property ivec2 renderWindowSize() const
    {
        return ivec2(width, height);
    }

    @property ref const(Config) config() const
    {
        return cfg;
    }

    @property long currentFrameIndex() const
    {
        return frameIndex;
    }

    void beginFrame()
    {

    }

    void endFrame()
    {

    }

    //Framebuffer getDefaultFramebuffer() { return screenFbo; }

private:
    GLImplementationLimits implLimits;
    Config cfg;
    //Fence frameFence;
    long frameIndex;
    int width;
    int height;
    //Framebuffer screenFbo;
    // Graphics frame capture
    long nextFrameCapture = -1;
}

private __gshared Context currentCtx;
