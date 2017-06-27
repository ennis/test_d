module engine.renderer.deferred;

import core.types;
import engine.frame_graph;
import gfx.draw;
import gfx.texture;
import core.imageformat;


struct GeometryBuffersSetupPass
{
    //int width;
    //int height;

    @Create {
        Texture depth;
        Texture normals;
        Texture diffuse; 
        Texture objectIDs;
        Texture velocity;
    }

    bool setup(
        ref PassMetadata!(GeometryBuffersSetupPass) md, 
        int w, int h) 
    {
        with (md.depth) {
            width = w;
            height = h;
            usage = FrameGraph.ResourceUsage.RenderTarget;
            fmt = ImageFormat.D32_SFLOAT;
        }

        with (md.normals) {
            width = w;
            height = h;
            usage = FrameGraph.ResourceUsage.RenderTarget;
            fmt = ImageFormat.A2R10G10B10_SNORM_PACK32;
        }

        with (md.diffuse) {
            width = w;
            height = h;
            usage = FrameGraph.ResourceUsage.RenderTarget;
            fmt = ImageFormat.R8G8B8A8_SRGB;
        }

        with (md.velocity) {
            width = w;
            height = h;
            usage = FrameGraph.ResourceUsage.RenderTarget;
            fmt = ImageFormat.R16G16_SFLOAT;
        }

        return true;
    }

    void execute()
    {
    }

    // Resource attributes:
    // Input/Output/Mutable
    // width, height, format
    // constraints (i.e. say that two textures must have the same size)
}


struct RenderScenePass 
{
  @Write {
    Texture depth;
    Texture normals;
    Texture diffuse; 
    Texture objectIDs;
    Texture velocity;
  }

  bool setup(ref PassMetadata!(GeometryBuffersSetupPass) md) 
  {
    // nothing to do
    return true;
  }

  void execute() 
  {
    // just draw stuff
  }
}

struct TemporalAAPass 
{
  @Read {
    Texture frame;
  }

  // persistent resource, so not managed by the frame graph
  Texture history;

  bool setup(ref PassMetadata!(TemporalAAPass) md, Texture historyTex) 
  {
    history = historyTex;
  }

}
