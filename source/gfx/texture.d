module gfx.texture;
import gfx.globject;
import gfx.glformatinfo;
import opengl;
import core.imageformat;

class Texture : GLObject
{
    enum Options
    {
        None,
        SparseStorage = (1 << 0)
    }

    override void release()
    {
        if (obj)
        {
            glDeleteTextures(1, &obj);
        }
    }

    /// Description of a texture used during creation
    struct Desc
    {
        ImageDimensions dims; //< Dimensions (1D,2D,3D,Array,Cube map...)
        ImageFormat fmt; //< Format, one of the ImageFormats
        int width; //< width
        int height; //< height, should be 1 for 1D textures
        int depth; //< depth, should be 1 for 1D or 2D textures
        int sampleCount; //< Number of samples. Setting sampleCount >= 1 will create
        //< a multisampled texture
        int mipMapCount; //< Number of mip maps
        Options opts; //< Texture creation flags. See Texture::Options for more
        //< information.
    }

    /// Default constructor: creates a null texture object
    /// (i.e. OpenGL object 0)
    this()
    {

    }

    /// Create a texture from the specified description
    this(const ref Desc desc)
    {
        this.desc = desc;

        switch (desc.dims)
        {
        case ImageDimensions.Image1D:
            target = GL_TEXTURE_1D;
            break;
        case ImageDimensions.Image2D:
            if (desc.sampleCount > 0)
            {
                target = GL_TEXTURE_2D_MULTISAMPLE;
            }
            else
            {
                target = GL_TEXTURE_2D;
            }
            break;
        case ImageDimensions.Image3D:
            target = GL_TEXTURE_3D;
            break;
        default:
            assert(0);
        }

        const auto glfmt = getGLImageFormatInfo(desc.fmt);
        GLuint tex_obj;
        glCreateTextures(target, 1, &tex_obj);
        if (desc.opts & Options.SparseStorage)
        {
            glTextureParameteri(tex_obj, GL_TEXTURE_SPARSE_ARB, GL_TRUE);
        }

        final switch (target)
        {
        case GL_TEXTURE_1D:
            glTextureStorage1D(tex_obj, desc.mipMapCount, glfmt.internal_fmt, desc.width);
            break;
        case GL_TEXTURE_2D:
            glTextureStorage2D(tex_obj, desc.mipMapCount, glfmt.internal_fmt,
                    desc.width, desc.height);
            break;
        case GL_TEXTURE_2D_MULTISAMPLE:
            glTextureStorage2DMultisample(tex_obj, desc.sampleCount,
                    glfmt.internal_fmt, desc.width, desc.height, true);
            break;
        case GL_TEXTURE_3D:
            glTextureStorage3D(tex_obj, 1, glfmt.internal_fmt, desc.width,
                    desc.height, desc.depth);
            break;
        }
        // set sensible defaults
        glTextureParameteri(tex_obj, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTextureParameteri(tex_obj, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTextureParameteri(tex_obj, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
        glTextureParameteri(tex_obj, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTextureParameteri(tex_obj, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        obj = tex_obj;
    }

    // Type-safe pixel data upload
    /*void updateRegion(T)(int x, int y, int z, int width, int height, int depth, T[] data)
        if (T.sizeof % 4 == 0)
    {
        // check data size
        assert(width*height*depth == data.length);
        // infer pixel transfer formats from T
        // ubyte[N]
        // float, vec2, vec3, vec4
        GLenum channels;
        GLenum type;

        static if (is(T == float)) {

        }
    }*/

    // Upload data (raw)
    // No check is performed on pixelData
    void updateRegionRaw(int mipLevel, int x, int y, int z, int width, int height, int depth, GLenum channels, GLenum type, void[] pixelData)
    {
        switch (desc.dims) with (ImageDimensions) {
        case Image1D:
            glTextureSubImage1D(obj, mipLevel, x, width,
                                channels, type, pixelData.ptr);
            break;
        case Image2D:
            glTextureSubImage2D(obj, mipLevel, x, y, width, height,
                                channels, type, pixelData.ptr);
            break;
        case Image3D:
            glTextureSubImage3D(obj, mipLevel, x, y, z, width,
                                height, depth, channels, type, pixelData.ptr);
            break;
        default: assert(false);
        }
    }

    // TODO replace this with immutable members
    @property auto width() const pure nothrow { return desc.width; }
    @property auto height() const pure nothrow { return desc.height; }
    @property auto depth() const pure nothrow { return desc.depth; }
    @property auto format() const pure nothrow { return desc.fmt; }
    @property auto dimensions() const pure nothrow { return desc.dims; }
    @property auto numMipLevels() const pure nothrow { return desc.mipMapCount; }
    @property auto options() const pure nothrow { return desc.opts; }

    //====================================
    // Named constructors

    /// Create a 1D texture
    /// See also Texture::MipMaps, Texture::Options
    static Texture create1D(ImageFormat fmt, int w, int mipMaps = 1, Options opts = Options.None)
    {
        Desc desc = {ImageDimensions.Image1D, fmt, w, 1, 1, 0, mipMaps, opts};
        return new Texture(desc);
    }

    /// Create a 2D texture. If ms.count != 0, a multisample texture is created
    /// See also Texture::MipMaps, Texture::Options
    static Texture create2D(ImageFormat fmt, int w, int h, int mipMaps = 1,
            int samples = 0, Options opts = Options.None)
    {
        // dfmt off
        Desc desc = {
            ImageDimensions.Image2D, fmt, w, h, 1, samples, mipMaps, opts};
        // dfmt on
        return new Texture(desc);
    }

    /// Create a 3D texture
    /// See also Texture::MipMaps, Texture::Options
    static Texture create3D(ImageFormat fmt, int w, int h, int d, int mipMaps = 1,
            Options opts = Options.None)
    {
        Desc desc = {ImageDimensions.Image3D, fmt, w, h, d, 0, mipMaps, opts};
        return new Texture(desc);
    }

    Desc desc;
    private GLenum target = GL_TEXTURE_2D;
}

