module engine.frame_graph;
import core.imageformat;
import core.dbg;
import core.interp;

import gfx.texture;
import gfx.buffer;

import std.typecons;
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

    // Renamed resource handle
    static struct Resource {
        SharedResource actual;      // pointer to the actual resource entry (Texture or buffer)
        ResourceUsage usage;    // how is the resource used
        int renameIndex;        // SSA index
    }

    static struct TextureResource {
        Resource thisResource;
        alias thisResource this;
        auto opCast(T)() if (Unqual!T == Resource) { return thisResource; }

        @property auto metadata() const { return (cast(Texture)actual).texdesc; }
        @property auto resource() const { return (cast(Texture)actual).texture; }
    }

    static struct BufferResource {
        Resource thisResource;
        alias thisResource this;
        auto opCast(T)() if (Unqual!T == Resource) { return thisResource; }

        @property auto metadata() const { 
            struct Return {
                size_t size;
                gfx.buffer.Buffer.Usage bufferUsage;
            }
            auto buf = cast(Buffer)actual;
            return Return(buf.size, buf.bufferUsage); 
        }
        @property auto resource() const { return (cast(Buffer)actual).buffer; }
    }

    // Texture creation metadata
    static struct TextureMetadata 
    {
        gfx.texture.Texture.Desc desc;
        alias desc this;
        float[4] clearColor;
    }

    struct PassBuilder 
    {
        // add r as a read dependency, specify usage
        Resource read(Resource r, ResourceUsage usage)
        {
            auto r2 = Resource(r.actual, usage, r.renameIndex);
            pass.reads ~= r2;
            return r2;
        }

        Resource write(Resource r, ResourceUsage usage)
        {
            auto w = Resource(r.actual, usage, r.renameIndex+1);
            pass.writes ~= w;
            return w;
        }

        TextureResource createTexture(ref const(gfx.texture.Texture.Desc) desc, ResourceUsage usage)
        {
            auto tex = fg.createTexture(desc);
            auto c = TextureResource(Resource(tex, usage, 0));
            pass.creates ~= c;
            return c;
        }

        BufferResource createBuffer(size_t size, gfx.buffer.Buffer.Usage bufferUsage, ResourceUsage usage) 
        {
            auto buf = fg.createBuffer(size, bufferUsage);
            auto c = BufferResource(Resource(buf, usage, 0));
            pass.creates ~= c;
            return c;
        }

        FrameGraph fg;
        Pass pass;
    }

    void compile() 
    {
        bool hasWriteConflicts = false;
        int[SharedResource] r_ren;    // read rename list (contains the rename index that
                        // should appear for the next read from a resource)
        int[SharedResource] w_ren;    // write rename list (contains the rename index that
                        // should appear for the next write to a resource)
        
        // first pass: lifetime calculation and concurrent resource usage detection
        foreach (passIndex, pass; passes)
        {
            foreach (r; pass.reads) {
                if (r_ren[r.actual] > r.renameIndex) {
                    warningMessage(
                        "[FrameGraph] read/write conflict detected on resource %s.%s",
                        r.actual.name, r.renameIndex);
                    hasWriteConflicts = true;
                }
                else 
                {
                    w_ren[r.actual] = r.renameIndex + 1;
                }
                // update lifetime end
                // resource is read during this pass, so the resource must outlive the pass
                if (r.actual.lifetime.end < passIndex) {
                    r.actual.lifetime.end = cast(int)passIndex;
                }
            }

            foreach (w; pass.writes) 
            {
                if (w.actual.lifetime.begin == -1) {
                    w.actual.lifetime.begin = cast(int)passIndex;
                }

                // Note: p.writes should not contain the same resource twice with a
                // different rename index
                if (w_ren[w.actual] > w.renameIndex) {
                    warningMessage(
                        "[FrameGraph] read/write conflict detected on resource %s.%s",
                        w.actual.name, w.renameIndex);
                    hasWriteConflicts = true;
                } else {
                    // the next pass cannot use this rename for write operations
                    //AG_DEBUG("write rename index for {}: .{} -> .{}", w.handle,
                    //         w.renameIndex, w.renameIndex + 1);
                    w_ren[w.actual] = w.renameIndex + 1;
                    r_ren[w.actual] = w.renameIndex;
                }
            }
        }

        // Second pass: resource allocation
        ReuseCache reuseCache;

        foreach (passIndex, p; passes) 
        {
            //AG_DEBUG("** PASS {}", p->name);
            // create resources that should be created
            foreach (create; p.creates) {
                create.actual.allocate(reuseCache);
            }

            // release read-from resources that should be released on this pass
            foreach (read; p.reads) {
                auto actual = read.actual;
                if (actual.lifetime.end <= passIndex) {
                    if (auto texres = cast(Texture)actual) {
                        // if it's a texture, add it into the reuse cache for recycling
                        reuseCache.textureInUse[texres.texture] = false;
                    }
                }
            }
        }

        // Print statistics about the allocated resources
        debugMessage("====== TEXTURES: ======");
        foreach (tex; reuseCache.allTextures) {
            import std.conv : to;
            import std.format : format;
            string typeStr = to!string(tex.dimensions);
            string formatStr = to!string(tex.format);
            string dbg = typeStr ~ ",";

            final switch (tex.dimensions) 
            {
            case ImageDimensions.Image1D: 
                dbg ~= format("%s", tex.width);
                break;
            case ImageDimensions.Image1DArray:
            case ImageDimensions.Image2D:
            case ImageDimensions.Image2DArray:
            case ImageDimensions.ImageCubeMap:
                dbg ~= format("%sx%s", tex.width, tex.height);
                break;
            case ImageDimensions.Image3D:
                dbg ~= format("%sx%sx%s", tex.width, tex.height, tex.depth);
                break;
            case ImageDimensions.Image3DArray:
                dbg ~= format("<???>");
                break;
            }

            dbg ~= format(",%s miplevels,", tex.numMipLevels);

            if (tex.options & gfx.texture.Texture.Options.SparseStorage) {
                dbg ~= "(Sparse)";
            }
            debugMessage("%s", dbg);
        }

        debugMessage("====== BUFFERS: ======");
        foreach (buf; reuseCache.allBuffers) {
            import std.conv : to;
            debugMessage("%s bytes, usage %s", buf.size, buf.usage);
        }

       /* auto assignTexture = [&](ResourceDesc::Texture &texdesc) {
            for (auto &&tex : textures) {
            if (texturesInUse.count(tex.get()))
                continue;
            auto ptex = tex.get();
            if (ptex->desc() == texdesc.desc) {
                //AG_DEBUG("[REUSING TEXTURE @{} {}x{}x{} {}]", (const void *)ptex,
                //         texdesc.desc.width, texdesc.desc.height, texdesc.desc.depth,
                //         getImageFormatInfo(texdesc.desc.fmt).name);
                texdesc.ptex = ptex;
                texturesInUse.insert(ptex);
                return;
            }
            }
            auto tex = std::make_unique<Texture>(texdesc.desc);
            auto ptex = tex.get();
            textures.push_back(std::move(tex));
            texturesInUse.insert(ptex);
            //AG_DEBUG("[creating new texture @{} {}x{}x{} {}]", (const void *)ptex,
            //         texdesc.desc.width, texdesc.desc.height, texdesc.desc.depth,
            //         getImageFormatInfo(texdesc.desc.fmt).name);
            texdesc.ptex = ptex;
        };*/

        /*auto assignBuffer = [&](ResourceDesc::Buffer &bufdesc) {
            auto buf = std::make_unique<Buffer>(bufdesc.size, bufdesc.usage);
            auto pbuf = buf.get();
            buffers.push_back(std::move(buf));
            //AG_DEBUG("[creating new buffer @{} of size {}]", (const void *)pbuf,
            //         bufdesc.size);
            bufdesc.buf = pbuf;
        };*/

       /* auto assignCompatibleResource = [&](ResourceDesc &rd) {
            if (auto ptexdesc = get_if<ResourceDesc::Texture>(&rd.v)) {
            assignTexture(*ptexdesc);
            } else if (auto pbufdesc = get_if<ResourceDesc::Buffer>(&rd.v)) {
            assignBuffer(*pbufdesc);
            // always create another buffer, for now
            }
        };*/

        /*auto releaseResource = [&](ResourceDesc &rd) {
            if (auto ptexdesc = get_if<ResourceDesc::Texture>(&rd.v)) {
            // AG_DEBUG("[RELEASE TEXTURE @{}]", (const void *)ptexdesc->ptex);
            texturesInUse.erase(ptexdesc->ptex);
            } else if (auto pbufdesc = get_if<ResourceDesc::Buffer>(&rd.v)) {
            // Nothing to do for buffers
            // assignBuffer(*pbufdesc);
            }
        };*/
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

    private 
    {
        struct ReuseCache 
        {
            gfx.texture.Texture[] allTextures;
            gfx.buffer.Buffer[] allBuffers;
            bool[gfx.texture.Texture] textureInUse;
        }

        static class SharedResource 
        {
            static struct Lifetime { 
                int begin = -1; 
                int end = -1; 
            }
            Lifetime lifetime;
            string name_;
            int lastRenameIndex = 0;    // last seen SSA index
            
            @property string name() const { return name_; }

            abstract SharedResource clone();
            abstract void allocate(ref ReuseCache reuse);
            abstract void release();
        }

        static class Texture : SharedResource 
        {
            gfx.texture.Texture.Desc texdesc;
            gfx.texture.Texture texture;   // can be aliased

            override Texture clone() const { return null; }

            override void allocate(ref ReuseCache reuse) 
            {
                foreach (t; reuse.allTextures) {
                    if (t.desc == texdesc && !reuse.textureInUse[t]) {
                        texture = t;
                        reuse.textureInUse[t] = true;
                        return;
                    }
                }
                // create new texture
                texture = new gfx.texture.Texture(texdesc);
                reuse.textureInUse[texture] = true;
                reuse.allTextures ~= texture;
            }

            override void release() 
            {
                if (texture)
                    texture.release();
            }
        }

        static class Buffer : SharedResource 
        {
            size_t size;
            gfx.buffer.Buffer.Usage bufferUsage;
            gfx.buffer.Buffer buffer;   // can be aliased

            override Buffer clone() const { return null; }
            
            // No aliasing
            override void allocate(ref ReuseCache reuse) 
            {
                buffer = new gfx.buffer.Buffer(bufferUsage, size);
                reuse.allBuffers ~= buffer;
            }

            override void release()
            {
                if (buffer)
                    buffer.release();
            }
        }

        class Pass
        {
            void cleanup() 
            {
                foreach(r; creates) {
                    r.actual.release();
                }
            }

            string name;
            Resource[] reads;
            Resource[] writes;
            Resource[] creates;
            // Private node data
            Variant data;
            // execution callback
            void delegate(Pass) execCallback;
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
        
        SharedResource[] resources;
        //gfx.buffer.Buffer[] buffers;
        //gfx.texture.Texture[] textures;
        Pass[] passes;
    }
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

// Bikeshedding: resource = actual resource + rename index
// => edge, dependency, value (nondescript), resource (confusion), SSA Resource (unclear), ResourceHandle (too long), handle (nondescript)
// => rename (unclear), variable (misleading)
//
// Descriptor => metadata
// 


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
        string outBody;
        foreach (a; names) {
            outBody ~= mixin(interp!fmt);
        }
        return outBody;
    }

    
}

private static template MembersWithUDAs(T, UDAs...) 
{
    string[] getMembersWithUDAs() 
    {
        import std.traits : hasUDA;
        string[] result;
        foreach (m; __traits(allMembers, T)) {
            foreach (UDA; UDAs) {
                if (hasUDA!(__traits(getMember, T, m), UDA)) {
                    result ~= m;
                }
            }
        }
        return result;
    }

    enum MembersWithUDAs = getMembersWithUDAs(); 
} 


template PassOutputs(T)
{
    struct PassOutputs
    {
        static enum Outputs = MembersWithUDAs!(T, Write, Create);
        static enum numOutputs = Outputs.length;
        mixin(genBody!("const(PassTypes!(typeof(T.${a})).ResourceType) ${a};")(Outputs));    
    }
}

template PassMetadata(T)
{
    static template PassTypes(U) 
    {
        static if (is(U == gfx.buffer.Buffer)) 
        {
            struct MetadataAndUsage {   
                size_t size;
                gfx.buffer.Buffer.Usage bufferUsage;
                FrameGraph.ResourceUsage usage;
            }
            struct MetadataAndUsage {   
                size_t size;
                gfx.buffer.Buffer.Usage bufferUsage;
                FrameGraph.ResourceUsage usage;
            }
            alias Resource = FrameGraph.Buffer;
        }
        else static if (is(U == gfx.texture.Texture)) 
        { 
            struct Metadata {
                gfx.texture.Texture.Desc desc;
                alias desc this;
                FrameGraph.ResourceUsage usage;
            }
            alias Resource = FrameGraph.Texture;
        }
        else {
            static assert(false, "Unsupported resource type: " ~ U.stringof);
        }
    }

    struct PassMetadata
    {
        import std.traits : getSymbolsByUDA;
        private static enum Created = MembersWithUDAs!(T, Create);
        private static enum ReadWrite = MembersWithUDAs!(T, Read, Write);

        // Read and write inputs/outputs
        mixin(genBody!("const(PassTypes!(typeof(T.${a})).Resource)* ${a};")(ReadWrite));  
        // Created transient resources
        mixin(genBody!("PassTypes!(typeof(T.${a})).Metadata ${a};")(Created));  
    }
}

template addPass(T) 
{
    PassOutputs!T addPass(Inputs...)(FrameGraph fg, Inputs inputs)
    {
        // For read/write: readonly metadata + writable flags
        // For create: writable metadata + writable flags 
        PassMetadata!(T) creationMetadata;

        //fg.addPass()
        // TODO init metadata with data in attributes
        foreach (i; inputs) {
            // cast input to expected Resource type (Texture or Buffer)
            // Verify against metadata already present
            // register Resource as input
        }
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

    @Create 
    //@FrameGraph.ResourceUsage.RenderTarget
    Texture depth;

    @Create Texture normals;
    @Create Texture diffuse; 
    @Create Texture objectIDs;
    @Create Texture velocity;

    bool setup(PassMetadata!(GeometryBuffers) metadata, int w, int h) 
    {
        // XXX Input texture descriptors should be immutable
        // Check at runtime?

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