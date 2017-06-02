module gfx.texture;
import gfx.globject;
import opengl;
import core.imageformat;

/// Structure containing information about the OpenGL internal format
/// corresponding to an 'ImageFormat'
struct GLFormatInfo
{
    GLenum internal_fmt; //< Corresponding internal format
    GLenum external_fmt; //< Preferred external format for uploads/reads (deprecated?)
    GLenum type; //< Preferred element type for uploads/reads
    int num_comp; //< number of components (channels) (TODO redundant)
    int size; //< Size of one pixel in bytes
};

immutable GLFormatInfo glfmt_rgba8_unorm = GLFormatInfo(GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE, 4, 4);

ref const(GLFormatInfo) getGLImageFormatInfo(ImageFormat fmt)
{
    switch (fmt)
    {
   // case ImageFormat.R32G32B32A32_UINT:
    //    return glfmt_rgba32_uint;
    //case ImageFormat.R16G16B16A16_SFLOAT:
    //    return glfmt_rgba16_float;
    case ImageFormat.R8G8B8A8_UNORM:
        return glfmt_rgba8_unorm;
    //case ImageFormat.R8G8B8A8_SNORM:
    //    return glfmt_r8_unorm;
   // case ImageFormat.R32_SFLOAT:
    //    return glfmt_r32_float;
   // case ImageFormat.R32G32_SFLOAT:
   //     return glfmt_rg32_float;
   // case ImageFormat.R32G32B32A32_SFLOAT:
   //     return glfmt_rgba32_float;
   // case ImageFormat.D32_SFLOAT:
   //     return glfmt_depth32_float;
   // case ImageFormat.A2R10G10B10_UNORM_PACK32:
    //    return glfmt_argb_10_10_10_2_unorm;
   // case ImageFormat.R8G8B8A8_SRGB:
   //     return glfmt_rgba8_unorm_srgb;
   // case ImageFormat.R16G16_SFLOAT:
   //     return glfmt_rg16_float;
   // case ImageFormat.R16G16_SINT:
   //     return glfmt_rg16_sint;
   // case ImageFormat.A2R10G10B10_SNORM_PACK32:
        // return glfmt_argb_10_10_10_2_snorm;   // there is no signed version of this
        // format in OpenGL
    default:
        assert(false, "Unsupported image format");
    }
}

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

        alias desc2 = this.desc;

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
        default: assert(0);
        }

        const auto glfmt = getGLImageFormatInfo(desc.fmt);
        GLuint tex_obj;
        glCreateTextures(target, 1, &tex_obj);
        if (desc.opts & Options.SparseStorage)
        {
            //glTextureParameteri(tex_obj, GL_TEXTURE_SPARSE_ARB, GL_TRUE);
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

    //====================================
    // Named constructors

    /// Create a 1D texture
    /// See also Texture::MipMaps, Texture::Options
    static Texture create1D(ImageFormat fmt, int w, int mipMaps = 1, Options opts = Options.None)
    {
        return null;
    }

    /// Create a 2D texture. If ms.count != 0, a multisample texture is created
    /// See also Texture::MipMaps, Texture::Options
    static Texture create2D(ImageFormat fmt, int w, int h, int mipMaps = 1,
            int samples = 0, Options opts = Options.None)
    {
        return null;
    }

    /// Create a 3D texture
    /// See also Texture::MipMaps, Texture::Options
    static Texture create3D(ImageFormat fmt, int w, int h, int d, int mipMaps = 1,
            Options opts = Options.None)
    {

        return null;
    }

    private Desc desc;
    private GLenum target = GL_TEXTURE_2D;
}
