module gfx.framebuffer;

import core.types;
import core.imageformat;
import gfx.globject;
import gfx.glformatinfo;
import gfx.texture;
import opengl;

class Renderbuffer : GLObject
{
public:

    this() {}

    this(ImageFormat format, int width, int height, int multisample = 0) {
        format_ = format;
        width_ = width;
        height_ = height;
        auto fmtinfo = getGLImageFormatInfo(format);
        glCreateRenderbuffers(1, &obj);
        if (multisample) {
	        glNamedRenderbufferStorageMultisample(obj, multisample, fmtinfo.internal_fmt, width, height);
        } else {
            glNamedRenderbufferStorage(obj, fmtinfo.internal_fmt, width, height);
        }
    }

    override void release() 
    {
        if (obj) {
            glDeleteRenderbuffers(1, &obj);
            obj = 0;
        }
    }

    @property auto format() const { return format_; }
    @property auto width() const { return width_; }
    @property auto height() const { return height_; }

private:
    ImageFormat format_;
    int width_;
    int height_;
}

class Framebuffer : GLObject
{
    this()
    {}

    void checkDimensions(int w, int h) {
        if (((width_ != 0) && (width_ != w)) || ((height_ != 0) && (height_ != h)))
        {
            assert(false, "The dimensions of the framebuffer attachements do not match");
        }
        else {
            width_ = w;
            height_ = h;
        }
    }

    override void release() 
    {
        if (obj) {
            glDeleteFramebuffers(1, &obj);
            obj = 0;
        }
    }
    
    void ensureInitialized() {
        immutable(GLenum[8]) drawBuffers = [
            GL_COLOR_ATTACHMENT0,     GL_COLOR_ATTACHMENT0 + 1,
            GL_COLOR_ATTACHMENT0 + 2, GL_COLOR_ATTACHMENT0 + 3,
            GL_COLOR_ATTACHMENT0 + 4, GL_COLOR_ATTACHMENT0 + 5,
            GL_COLOR_ATTACHMENT0 + 6, GL_COLOR_ATTACHMENT0 + 7];
        if (!obj) {
            glCreateFramebuffers(1, &obj);
            // do this once
            glNamedFramebufferDrawBuffers(obj, 8, drawBuffers.ptr);
        }
    }
    
    void setAttachement(GLenum attachement, GLuint tex) {
        ensureInitialized();
        glNamedFramebufferTexture(obj, attachement, tex, 0);
    }

    void setAttachement(GLenum attachement, Texture tex) {
        checkDimensions(tex.width, tex.height);
        setAttachement(attachement, tex.object);
    }

    void setRenderbufferAttachement(GLenum attachement, Renderbuffer renderbuffer) {
        checkDimensions(renderbuffer.width, renderbuffer.height);
        ensureInitialized();
        glNamedFramebufferRenderbuffer(obj, attachement, GL_RENDERBUFFER,
                                    renderbuffer.object);
    }

    bool ensureComplete()
    {
        auto s = glCheckNamedFramebufferStatus(obj, GL_DRAW_FRAMEBUFFER);
        assert(s == GL_FRAMEBUFFER_COMPLETE);
        return s == GL_FRAMEBUFFER_COMPLETE;
    }

    @property auto width() const { return width_; }
    @property auto height() const { return height_; }

private:
    int width_;
    int height_;
}
