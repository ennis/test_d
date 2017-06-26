module engine.renderer.deferred;

import engine.frame_graph;
import gfx.draw;

struct GeometryBuffers
{
    FrameGraph.TextureResource depth;
    FrameGraph.TextureResource diffuse;
    FrameGraph.TextureResource normals;
    FrameGraph.TextureResource objectIDs;
    FrameGraph.TextureResource velocity;
}

GeometryBuffers initializeGeometryBuffers(FrameGraph frameGraph, int width, int height)
{

  return frameGraph.addPass!(GeometryBuffers)("GeometryBuffers",
      //////////////////////////////////////////////////////
      // SETUP
      (FrameGraph.PassBuilder builder, ref GeometryBuffers data) 
      {
        data.depth = builder.createTexture(ImageFormat.D32_SFLOAT, width,
                                             height, "depth");
        data.diffuse = builder.createTexture(ImageFormat.R8G8B8A8_UNORM,
                                               width, height, "diffuse");
        data.normals = builder.createTexture(ImageFormat.R16G16_SFLOAT,
                                               width, height, "normals");
        data.objectIDs = builder.createTexture(ImageFormat.R16G16_SINT,
                                                 width, height, "objectIDs");
        data.velocity = builder.createTexture(ImageFormat.R32G32_SFLOAT,
                                                width, height, "velocity");
      },
      //////////////////////////////////////////////////////
      // EXECUTE
      (ref GeometryBuffers data) {
        // Clear targets
        clearTexture(data.diffuse.texture, vec4(0.0f, 0.0f, 0.0f, 1.0f));
        clearTexture(data.normals.texture, vec4(0.5f, 0.5f, 0.0f, 1.0f));
        clearTexture(data.objectIDs.texture, ivec4(0, 0, 0, 0));
        clearDepthTexture(data.depth.texture, 0.0f);
        clearTexture(data.velocity.texture, vec4(0.0f, 0.0f, 0.0f, 1.0f));
      });
}
