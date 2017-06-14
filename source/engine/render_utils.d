module engine.render_utils;

import core.cache;
import gfx.texture;
import gfx.buffer;
import gfx.draw;
import gfx.sampler;
import engine.pipeline;
import engine.globals;
 
private class State 
{
    this(Cache cache = getDefaultCache()) 
    {
        reloadShaders(cache);
    }

    void reloadShaders(Cache cache) {
        drawSpriteShader = new GraphicsPipeline(cache, "resources/shaders/default.lua$drawSprite");
        drawMeshShader = new GraphicsPipeline(cache, "resources/shaders/default.lua$drawMeshDefault");
        drawWireMeshShader = new GraphicsPipeline(cache, "resources/shaders/default.lua$drawWireMesh");
        drawWireMeshNoDepthShader = new GraphicsPipeline(cache, "resources/shaders/default.lua$drawWireMeshNoDepth");
        drawWireMesh2DColorShader = new GraphicsPipeline(cache, "resources/shaders/default.lua$drawWireMesh2DColor");
    }

    Sampler samplerNearest;
    Sampler samplerLinear;
    GraphicsPipeline drawSpriteShader;
    GraphicsPipeline drawMeshShader;
    GraphicsPipeline drawWireMeshShader;
    GraphicsPipeline drawWireMeshNoDepthShader;
    GraphicsPipeline drawWireMesh2DColorShader;
}

private auto getState()
{
    import std.concurrency : initOnce;
    static __gshared State renderUtilsState;
    initOnce!(renderUtilsState)(new State());
    return renderUtilsState;
}