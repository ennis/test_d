module engine.renderer.deferred;

import core.types;
import engine.frame_graph;
import engine.pipeline;
import engine.scene_object;
import engine.mesh;
import gfx.draw;
import gfx.texture;
import core.imageformat;


struct GeometryBuffersSetupPass
{
    mixin Pass;
    //int width;
    //int height;

    @Create {
        Texture depth;
        Texture normals;
        Texture diffuse; 
        Texture objectIDs;
        Texture velocity;
    }

    bool setup(int w, int h) 
    {
        with (metadata.depth) {
            width = w;
            height = h;
            usage = FrameGraph.ResourceUsage.RenderTarget;
            fmt = ImageFormat.D32_SFLOAT;
        }

        with (metadata.normals) {
            width = w;
            height = h;
            usage = FrameGraph.ResourceUsage.RenderTarget;
            fmt = ImageFormat.A2R10G10B10_SNORM_PACK32;
        }

        with (metadata.diffuse) {
            width = w;
            height = h;
            usage = FrameGraph.ResourceUsage.RenderTarget;
            fmt = ImageFormat.R8G8B8A8_SRGB;
        }

        with (metadata.velocity) {
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
}


struct RenderScenePass 
{
  mixin Pass;

  @Write {
    Texture depth;
    Texture normals;
    Texture diffuse; 
    Texture objectIDs;
    Texture velocity;
  }

  bool setup() 
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
  mixin Pass;

  @Read {
    Texture frame;
  }

  // persistent resource, so not managed by the frame graph
  Texture history;

  bool setup(Texture historyTex) 
  {
    history = historyTex;
    return true;
  }

}
