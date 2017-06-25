module engine.frame_graph;
import core.imageformat;
import core.dbg;
import core.interp;

import gfx.texture;
import gfx.buffer;

import std.variant;

class FrameGraph 
{
    enum ResourceUsage {
        Default,
        ImageReadWrite,
        SampledTexture,
        RenderTarget,
        TransformFeedbackOutput,
    }

    static class SharedResource 
    {
        private 
        {
            static struct Lifetime { 
                int begin = -1; 
                int end = -1; 
            }
            Lifetime lifetime;
            string name_;
            int lastRenameIndex = 0;    // last seen SSA index
        }

        @property string name() const { return name_; }

        abstract SharedResource clone();
    }

    static class Texture : SharedResource {
        gfx.texture.Texture.Desc texdesc;
        gfx.texture.Texture texture;   // can be aliased
        alias texdesc this;

        override Texture clone() const { return null; }
    }

    static class Buffer : SharedResource {
        size_t size;
        gfx.buffer.Buffer.Usage bufferUsage;
        gfx.buffer.Buffer buffer;   // can be aliased

        override Buffer clone() const { return null; }
    }

    // Renamed resource handle
    static struct Resource {
        SharedResource sharedResource;      // pointer to the resource entry (Texture or buffer)
        ResourceUsage usage;    // how is the resource used
        int renameIndex;        // SSA index
    }

    class Pass
    {
        string name;
        Resource[] reads;
        Resource[] writes;
        Resource[] creates;
        // Private node data
        Variant data;
        // execution callback
        void delegate(Pass) execCallback;
    }

    struct PassBuilder 
    {
        // add r as a read dependency, specify usage
        Resource read(Resource r, ResourceUsage usage)
        {
            auto r = Resource(r.sharedResource, usage, r.renameIndex);
            pass.reads ~= r;
            return r;
        }

        Resource write(Resource r, ResourceUsage usage)
        {
            auto w = Resource(r.sharedResource, usage, r.renameIndex+1);
            pass.writes ~= w;
            return w;
        }

        Resource createTexture(ref const(gfx.texture.Texture.Desc) desc, ResourceUsage usage)
        {
            auto tex = fg.createTexture(desc);
            auto c = Resource(tex, usage, 0);
            pass.creates ~= c;
            return c;
        }

        void createBuffer(size_t size, gfx.buffer.Buffer.Usage bufferUsage, ResourceUsage usage) 
        {
            auto tex = fg.createBuffer(size, bufferUsage);
            auto c = Resource(tex, usage, 0);
            pass.creates ~= c;
            return c;
        }

        FrameGraph fg;
        Pass pass;
    }

    // Create a transient texture
    Texture createTexture(ref const(gfx.texture.Texture.Desc) desc) 
    {
        auto tex = new Texture();
        tex.texdesc = desc;
        resources ~= tex;
        return null;
    }

    // Create a transient buffer
    Buffer createBuffer(size_t size, gfx.buffer.Buffer.Usage bufferUsage)
    {
        auto buf = new Buffer();
        buf.size = size;
        buf.bufferUsage = bufferUsage;
        resources ~= buf;
        return null;
    }

    void compile() 
    {
        bool hasWriteConflicts = false;
        int[Resource] r_ren;    // read rename list (contains the rename index that
                        // should appear for the next read from a resource)
        int[Resource] w_ren;    // write rename list (contains the rename index that
                        // should appear for the next write to a resource)
        
        // first pass: lifetime calculation and concurrent resource usage detection
        foreach (passIndex, pass; passes)
        {
            foreach (r; pass.reads) {
                if (r_ren[r.resource] > r.renameIndex) {
                    warningMessage(
                        "[FrameGraph] read/write conflict detected on resource %s.%s",
                        r.resource.name, r.renameIndex);
                    hasWriteConflicts = true;
                }
                else 
                {
                    w_ren[r.resource] = r.renameIndex + 1;
                }
                // update lifetime end
                // resource is read during this pass, so the resource must outlive the pass
                if (r.resource.lifetime.end < passIndex) {
                    r.resource.lifetime.end = cast(int)passIndex;
                }
            }

            foreach (w; pass.writes) 
            {
                if (w.resource.lifetime.begin == -1) {
                    w.resource.lifetime.begin = cast(int)passIndex;
                }

                // Note: p.writes should not contain the same resource twice with a
                // different rename index
                if (w_ren[w.resource] > w.renameIndex) {
                    warningMessage(
                        "[FrameGraph] read/write conflict detected on resource %s.%s",
                        w.resource.name, w.renameIndex);
                    hasWriteConflicts = true;
                } else {
                    // the next pass cannot use this rename for write operations
                    //AG_DEBUG("write rename index for {}: .{} -> .{}", w.handle,
                    //         w.renameIndex, w.renameIndex + 1);
                    w_ren[w.resource] = w.renameIndex + 1;
                    r_ren[w.resource] = w.renameIndex;
                }
            }

        }
    }

    Pass addPass(PrivateData, Setup, Execute)(string name, Setup setup, Execute execute)
    {
        auto pass = new Pass();
        auto passBuilder = PassBuilder(this, pass);
        auto privateData = new PrivateData();
        pass.data = privateData;
        pass.name = name;
        setup(passBuilder, *privateData);
        pass.execCallback = (Pass p) {
            //execute()
        };
    }

    PassOutputs!T addPass(T, Args...)(Args args)
    {

    }

    Resource[] resources;
    gfx.buffer.Buffer[] buffers;
    gfx.texture.Texture[] textures;
    Pass[] passes;
}

// 1. Enter addPass!(T)
// 2. Create Pass!(T) instance
// 3. Initialize resources Pass!(T) from input arguments
// 4. call setup()

// Manual pass initialization:
// Call PassBuilder(frameGraph...)
// register inputs and outputs, create resources
// call fg.addPass(PassBuilder, <execution callback>, <private data>)
// fg.addPass moves the private data into a variant object
// private data should contain inputs and outputs


struct Create
{}

struct Read
{}

struct Write
{}

private 
{
    static enum aliasStr(alias U) = U.stringof;
    static string genBody(string fmt)(string[] names)
    {
        import std.meta : staticMap;
        string outBody;
        foreach (a; names) {
            outBody ~= mixin(interp!fmt);
        }
        return outBody;
    }

    static template PassTypes(U) 
    {
        static if (is(U == gfx.buffer.Buffer)) 
        {
            struct DescriptorType {   
                size_t size;
                gfx.buffer.Buffer.Usage bufferUsage;
                FrameGraph.ResourceUsage usage;
            }
            alias ResourceType = FrameGraph.Buffer;
        }
        else static if (is(U == gfx.texture.Texture)) 
        { 
            struct DescriptorType {
                gfx.texture.Texture.Desc desc;
                alias desc this;
                FrameGraph.ResourceUsage usage;
            }
            alias ResourceType = FrameGraph.Texture;
        }
        else {
            static assert(false, "Unsupported resource type: " ~ U.stringof);
        }
    }
}

template PassOutputs(T)
{
    struct PassOutputs
    {
        import std.traits : getSymbolsByUDA;
        static enum Outputs = cast(string[])[staticMap!(aliasStr, getSymbolsByUDA!(T, Create), getSymbolsByUDA!(T, Write))];
        static enum numOutputs = Outputs.length;
        mixin(genBody!("const(PassTypes!(typeof(T.${a})).ResourceType) ${a};")(Outputs));    
    }
}

template PassMetadata(T)
{
    class PassMetadata
    {
        import std.traits : getSymbolsByUDA;

        // Created transient resources
        mixin(genBody!("PassTypes!(typeof(T.${a})).DescriptorType ${a};", getSymbolsByUDA!(T, Create))());

        // Read and write inputs/outputs
        mixin(genBody!("const(PassTypes!(typeof(T.${a})).DescriptorType) ${a};", getSymbolsByUDA!(T, Read), getSymbolsByUDA!(T, Write))());    
    }

}


// Handle type | PassResources
// RTexture    | Texture
// RBuffer     | Buffer
// 

struct GeometryBuffers
{
    //int width;
    //int height;

    @Create Texture depth;
    @Create Texture normals;
    @Create Texture diffuse; 
    @Create Texture objectIDs;
    @Create Texture velocity;

    bool setup(PassMetadata!(GeometryBuffers) meta, int w, int h) 
    {
        // XXX Input texture descriptors should be immutable
        // Check at runtime?

        with (meta.depth) {
            width = w;
            height = h;
            usage = FrameGraph.ResourceUsage.RenderTarget;
            fmt = ImageFormat.D32_SFLOAT;
        }

        with (meta.normals) {
            width = w;
            height = h;
            usage = FrameGraph.ResourceUsage.RenderTarget;
            fmt = ImageFormat.A2R10G10B10_SNORM_PACK32;
        }

        with (meta.diffuse) {
            width = w;
            height = h;
            usage = FrameGraph.ResourceUsage.RenderTarget;
            fmt = ImageFormat.R8G8B8A8_SRGB;
        }

        with (meta.velocity) {
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
    
    //pragma(msg, __traits(allMembers, Pass!(GeometryBuffers).Outputs));

unittest 
{

}

//
// addPass<Type>(inputParameters...) -> outputParameters
// where: inputParameters are mapped somehow to the input resources described in the NodeType
// outputParameters is a synthesized struct containing the output resources

// pass = two delegates + per-node data
// one immediately executed that checks the nodes, creates outputs
//
// auto gbuffers = initializeGeometryBuffers(fg, w, h);
//
// automatically synthesize PassResources with correct members from the data

// @OutputTexture -> created
// @InputTexture -> read from 
// @InOutTexture -> read/write
//
// alias T = NodeTy!(GeometryBuffers)
// T gbuffers;
// gbuffers.width = ...;
// gbuffers.height = ...;
// 