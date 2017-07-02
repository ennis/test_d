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
    enum ResourceUsage
    {
        Default,
        ImageReadWrite,
        SampledTexture,
        RenderTarget,
        TransformFeedbackOutput,
    }

    // Renamed resource handle
    static struct Handle
    {
        LogicalResource resource; // pointer to the actual resource entry (Texture or buffer)
        ResourceUsage usage; // how is the resource used
        int renameIndex; // SSA index
    }

    /*static struct TextureResource {
        Resource thisResource;
        alias thisResource this;
        auto opCast(T)() if (Unqual!T == Resource) { return thisResource; }

        @property auto metadata() const { return (cast(Texture)actual).texdesc; }
        @property auto resource() const { return (cast(Texture)actual).texture; }
    }

    static struct BufferResource {
        Resource thisResource;
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
    }*/

    struct PassBuilder
    {
        // add r as a read dependency, specify usage
        Handle read(Handle r, ResourceUsage usage)
        {
            auto r2 = Handle(r.resource, usage, r.renameIndex);
            pass.reads ~= r2;
            return r2;
        }

        Handle write(Handle r, ResourceUsage usage)
        {
            auto w = Handle(r.resource, usage, r.renameIndex + 1);
            pass.writes ~= w;
            return w;
        }

        Handle createTexture(ref const(gfx.texture.Texture.Desc) desc, ResourceUsage usage)
        {
            auto tex = fg.createTexture(desc);
            auto c = Handle(tex, usage, 0);
            pass.creates ~= c;
            return c;
        }

        Handle createBuffer(size_t size, gfx.buffer.Buffer.Usage bufferUsage, ResourceUsage usage)
        {
            auto buf = fg.createBuffer(size, bufferUsage);
            auto c = Handle(buf, usage, 0);
            pass.creates ~= c;
            return c;
        }

        FrameGraph fg;
        Pass pass;
    }

    void compile()
    {
        bool hasWriteConflicts = false;
        int[LogicalResource] r_ren; // read rename list (contains the rename index that
        // should appear for the next read from a resource)
        int[LogicalResource] w_ren; // write rename list (contains the rename index that
        // should appear for the next write to a resource)

        // first pass: lifetime calculation and concurrent resource usage detection
        foreach (passIndex, pass; passes)
        {
            foreach (r; pass.reads)
            {
                if (r_ren[r.resource] > r.renameIndex)
                {
                    warningMessage("[FrameGraph] read/write conflict detected on resource %s.%s",
                            r.resource.name, r.renameIndex);
                    hasWriteConflicts = true;
                }
                else
                {
                    w_ren[r.resource] = r.renameIndex + 1;
                }
                // update lifetime end
                // resource is read during this pass, so the resource must outlive the pass
                if (r.resource.lifetime.end < passIndex)
                {
                    r.resource.lifetime.end = cast(int) passIndex;
                }
            }

            foreach (w; pass.writes)
            {
                if (w.resource.lifetime.begin == -1)
                {
                    w.resource.lifetime.begin = cast(int) passIndex;
                }

                // Note: p.writes should not contain the same resource twice with a
                // different rename index
                if (w.resource in w_ren && w_ren[w.resource] > w.renameIndex)
                {
                    warningMessage("[FrameGraph] read/write conflict detected on resource %s.%s",
                            w.resource.name, w.renameIndex);
                    hasWriteConflicts = true;
                }
                else
                {
                    // the next pass cannot use this rename for write operations
                    //AG_DEBUG("write rename index for {}: .{} -> .{}", w.handle,
                    //         w.renameIndex, w.renameIndex + 1);
                    w_ren[w.resource] = w.renameIndex + 1;
                    r_ren[w.resource] = w.renameIndex;
                }
            }
        }

        // Second pass: resource allocation
        ReuseCache reuseCache;

        foreach (passIndex, p; passes)
        {
            //AG_DEBUG("** PASS {}", p->name);
            // create resources that should be created
            foreach (create; p.creates)
            {
                create.resource.allocate(reuseCache);
            }

            // release read-from resources that should be released on this pass
            foreach (read; p.reads)
            {
                auto resource = read.resource;
                if (resource.lifetime.end <= passIndex)
                {
                    if (auto texres = cast(TextureResource) resource)
                    {
                        // if it's a texture, add it into the reuse cache for recycling
                        reuseCache.textureInUse[texres.texture] = false;
                    }
                }
            }
        }

        // Print statistics about the allocated resources
        debugMessage("====== TEXTURES: ======");
        foreach (tex; reuseCache.allTextures)
        {
            import std.conv : to;
            import std.format : format;

            immutable typeStr = to!string(tex.dimensions);
            immutable formatStr = to!string(tex.format);
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
                dbg ~= format("%sx%sx%s", tex.width,
                        tex.height, tex.depth);
                break;
            case ImageDimensions.Image3DArray:
                dbg ~= format("<???>");
                break;
            }

            dbg ~= format(",%s miplevels,", tex.numMipLevels);

            if (tex.options & gfx.texture.Texture.Options.SparseStorage)
            {
                dbg ~= "(Sparse)";
            }
            debugMessage("%s", dbg);
        }

        debugMessage("====== BUFFERS: ======");
        foreach (buf; reuseCache.allBuffers)
        {
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

    PrivateData* createPass(PrivateData, Setup, Execute)(string name, Setup setup, Execute execute)
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
        passes ~= pass;
        return privateData;
    }

    private
    {
        struct ReuseCache
        {
            gfx.texture.Texture[] allTextures;
            gfx.buffer.Buffer[] allBuffers;
            bool[gfx.texture.Texture] textureInUse;
        }

        static class LogicalResource
        {
            static struct Lifetime
            {
                int begin = -1;
                int end = -1;
            }

            Lifetime lifetime;
            string name_;
            int lastRenameIndex = 0; // last seen SSA index

            @property string name() const
            {
                return name_;
            }

            abstract LogicalResource clone();
            abstract void allocate(ref ReuseCache reuse);
            abstract void release();
        }

        static class TextureResource : LogicalResource
        {
            static struct Metadata
            {
                gfx.texture.Texture.Desc desc;
                alias desc this;
            }

            alias ConcreteResource = gfx.texture.Texture;

            Metadata md;
            gfx.texture.Texture texture; // can be aliased

            override TextureResource clone() const
            {
                return null;
            }

            override void allocate(ref ReuseCache reuse)
            {
                foreach (t; reuse.allTextures)
                {
                    if (t.desc == md.desc && !reuse.textureInUse[t])
                    {
                        texture = t;
                        reuse.textureInUse[t] = true;
                        return;
                    }
                }
                // create new texture
                texture = new gfx.texture.Texture(md.desc);
                reuse.textureInUse[texture] = true;
                reuse.allTextures ~= texture;
            }

            override void release()
            {
                if (texture)
                    texture.release();
            }
        }

        static class BufferResource : LogicalResource
        {
            static struct Metadata
            {
                size_t size;
                gfx.buffer.Buffer.Usage bufferUsage;
            }

            alias ConcreteResource = gfx.buffer.Buffer;

            Metadata md;
            gfx.buffer.Buffer buffer; // can be aliased

            override BufferResource clone() const
            {
                return null;
            }

            // No aliasing
            override void allocate(ref ReuseCache reuse)
            {
                buffer = new gfx.buffer.Buffer(md.bufferUsage, md.size);
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
                foreach (r; creates)
                {
                    r.resource.release();
                }
            }

            string name;
            Handle[] reads;
            Handle[] writes;
            Handle[] creates;
            // Private node data
            Variant data;
            // execution callback
            void delegate(Pass) execCallback;
        }

        // Create a transient texture
        TextureResource createTexture(ref const(gfx.texture.Texture.Desc) desc)
        {
            auto tex = new TextureResource();
            tex.md.desc = desc;
            resources ~= tex;
            return tex;
        }

        // Create a transient buffer
        BufferResource createBuffer(size_t size, gfx.buffer.Buffer.Usage bufferUsage)
        {
            auto buf = new BufferResource();
            buf.md.size = size;
            buf.md.bufferUsage = bufferUsage;
            resources ~= buf;
            return buf;
        }

        LogicalResource[] resources;
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
{
}

struct Read
{
}

struct Write
{
}

static string genBody(string fmt)(string[] names)
{
    string outBody;
    foreach (a; names)
    {
        outBody ~= mixin(interp!fmt);
    }
    return outBody;
}

static template MembersWithUDAs(T, UDAs...)
{
    string[] getMembersWithUDAs()
    {
        import std.traits : hasUDA;

        string[] result;
        foreach (m; __traits(allMembers, T))
        {
            foreach (UDA; UDAs)
            {
                if (hasUDA!(__traits(getMember, T, m), UDA))
                {
                    result ~= m;
                }
            }
        }
        return result;
    }

    enum MembersWithUDAs = getMembersWithUDAs();
}

template ConcreteToLogicalResource(T)
{
    static if (is(T == gfx.buffer.Buffer))
    {
        alias ConcreteToLogicalResource = FrameGraph.BufferResource;
    }
    else static if (is(T == gfx.texture.Texture))
    {
        alias ConcreteToLogicalResource = FrameGraph.TextureResource;
    }
}

// Writable metadata, for resources created in the pass (@Create)
struct MetadataAndUsage(U)
{
    ConcreteToLogicalResource!(U).Metadata metadata;
    alias metadata this;
    FrameGraph.ResourceUsage usage;
}

// Constant metadata, for resources created outside the pass (@Read, @Write)
struct ConstMetadataAndUsage(U)
{
    const(ConcreteToLogicalResource!(U).Metadata)* metadata;
    alias metadata this;
    FrameGraph.ResourceUsage usage;
}

mixin template Pass(T)
{

    struct Metadata
    {
        // Read and write inputs/outputs
        mixin(genBody!(q{
            ConstMetadataAndUsage!(typeof(T.${a})) ${a};
        })(MembersWithUDAs!(T, Read, Write)));

        // Created transient resources
        mixin(genBody!(q{
            MetadataAndUsage!(typeof(T.${a})) ${a};
        })(MembersWithUDAs!(T, Create)));
    }

    struct Handles
    {
        mixin(genBody!(q{
            FrameGraph.Handle ${a};
        })(MembersWithUDAs!(T, Read, Write, Create)));
    }

    T resources;
    alias resources this;
    Metadata metadata;
    Handles handles;
}

// PassTypes
// 

template addPass(T)
{
    // helper function to get the metadata of a handle
    auto getMetadata(U)(FrameGraph.Handle h)
    {
        static if (is(U == FrameGraph.BufferResource))
        {
            return &(cast(FrameGraph.BufferResource) h.resource).md;
        }
        else static if (is(U == FrameGraph.TextureResource))
        {
            return &(cast(FrameGraph.TextureResource) h.resource).md;
        }
        else
            static assert(false, "Unexpected type");
    }

    auto createResource(MD)(FrameGraph.PassBuilder passBuilder, ref MD metadata)
    {
        static if (is(MD == MetadataAndUsage!(gfx.buffer.Buffer)))
        {
            return passBuilder.createBuffer(metadata.size, metadata.bufferUsage, metadata.usage);
        }
        else static if (is(MD == MetadataAndUsage!(gfx.texture.Texture)))
        {
            return passBuilder.createTexture(metadata.desc, metadata.usage);
        }
        else
            static assert(false, "Unexpected type");
    }

    auto addPass(InputTuple, Args...)(FrameGraph fg, InputTuple inputs, Args args)
            if (is(InputTuple : Tuple!(Inputs), Inputs...))
    {
        import std.traits : hasUDA;
        import std.meta : aliasSeqOf;
        immutable inputNames = MembersWithUDAs!(typeof(T.resources), Read, Write);

        auto passData = fg.createPass!(T)(T.stringof,
        ///////////////////// SETUP /////////////////////
        (ref FrameGraph.PassBuilder pb, ref T data) {
            auto passResources = &data.resources;
            auto passHandles = &data.handles;
            auto passMetadata = &data.metadata;
            // Set metadata for inputs
            foreach (i, input; inputs.expand)
            {
                __traits(getMember, passMetadata, inputNames[i]).metadata = getMetadata!(
                    ConcreteToLogicalResource!(typeof(__traits(getMember,
                    passResources, inputNames[i]))))(input);

                debugMessage("input %s", inputNames[i]);
            }
            // Call setup
            data.setup(args); 
            // Register inputs
            foreach (i, input; inputs.expand)
            { 
                if (hasUDA!(__traits(getMember, typeof(data.resources), inputNames[i]), Read))
                {
                    // Read access
                    __traits(getMember, passHandles, inputNames[i]) = pb.read(input, __traits(getMember, passMetadata, inputNames[i]).usage);
                }
                else
                {
                    // Write access
                    __traits(getMember, passHandles, inputNames[i]) = pb.write(input, __traits(getMember, passMetadata, inputNames[i]).usage);
                }
            }
            // Create pass resources
            foreach (created; aliasSeqOf!(MembersWithUDAs!(typeof(T.resources), Create)))
            {
                __traits(getMember, passHandles, created) = createResource(pb,
                    __traits(getMember, passMetadata, created));
            }
        },
        ///////////////////// EXECUTE /////////////////////
        (ref T data) {
            // copy concrete resources
            auto passResources = &data.resources;
            auto passHandles = &data.handles;
            foreach (res; aliasSeqOf!([__traits(allMembers, typeof(data.resources))]))
            {
                __traits(getMember, passResources, res) = cast(typeof(__traits(getMember,
                    passResources, res)))(__traits(getMember, passHandles, res).resource);
            }
            // execute
            data.execute();
        });

        static struct PassOutputs
        {
            mixin(genBody!("FrameGraph.Handle ${a};")(MembersWithUDAs!(typeof(T.resources), Create, Write)));
        }

        // Init outputs
        PassOutputs outputs;
        auto passHandles = &passData.handles;
        foreach (output; __traits(allMembers, PassOutputs))
        {
            __traits(getMember, outputs, output) = __traits(getMember, passHandles, output);
        }

        return outputs;
    }
}

// Handle type | PassResources
// RTexture    | Texture
// RBuffer     | Buffer
// 

// Creation metadata (example for textures)
// - Texture.Desc
// - Clear color (or depth)
// - initial resource usage
//
// if @Create: const(Metadata)*, else Metadata
//
// addPass!(GeometryBuffersSetupPass)(frameGraph, tuple(...), ...);
//

struct GeometryBuffers
{
    struct Resources
    {
        @Read
        {
            Texture initial;
        }

        @Create
        {
            Texture depth;
            Texture normals;
            Texture diffuse;
            Texture objectIDs;
            Texture velocity;
        }
    }

    mixin Pass!(Resources);

    bool setup(int w, int h)
    {
        with (metadata.depth)
        {
            width = w;
            height = h;
            usage = FrameGraph.ResourceUsage.RenderTarget;
            fmt = ImageFormat.D32_SFLOAT;
        }

        with (metadata.normals)
        {
            width = w;
            height = h;
            usage = FrameGraph.ResourceUsage.RenderTarget;
            fmt = ImageFormat.A2R10G10B10_SNORM_PACK32;
        }

        with (metadata.diffuse)
        {
            width = w;
            height = h;
            usage = FrameGraph.ResourceUsage.RenderTarget;
            fmt = ImageFormat.R8G8B8A8_SRGB;
        }

        with (metadata.velocity)
        {
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
    FrameGraph fg;
    FrameGraph.Handle h1;
    FrameGraph.Handle h2;

    auto outputs = fg.addPass!(GeometryBuffers)(tuple(), 640, 480);
    static assert(__traits(compiles, outputs.normals));
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
