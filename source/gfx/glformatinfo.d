module gfx.glformatinfo;
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