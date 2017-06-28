module engine.pipeline;
import core.dbg;
import core.cache;
import gfx.state_group;
import luad.all;
import opengl;
import gfx.vertex_array;
import gfx.bind;
import gfx.shader;

/// Useless base class
class GPUPipeline
{
}

/// When should we cache?
///     -> Once the description is loaded
/// What should we cache?
///     -> The program
///     -> The VAO
///     -> The loaded pipeline description
///     -> all in one
class GraphicsPipeline : GPUPipeline
{
    static struct Desc
    {
        string shaderFile;
        immutable(BlendState)[] blendState;
        GLbitfield barrierBits;
        DepthStencilState depthStencilState;
        RasterizerState rasterizerState;
        immutable(VertexAttribute)[] layout;
        immutable(string)[] defines;
        string vertexShader;
        string fragmentShader;
        string geometryShader;
        string tessControlShader;
        string tessEvalShader;

        static Desc fromFile(string path, string subPath)
        {
            static struct LuaDesc
            {
                string shaderFile;
                string shaderSource;
                BlendState[] blendState;
                GLbitfield barrierBits;
                DepthStencilState depthStencilState;
                RasterizerState rasterizerState;
                VertexAttribute[] layout;
                string[] defines;
            }

            //import std.string : 
            auto lua = new LuaState;
            lua.openLibs();
            lua.doFile(path);
            // Deserialize from Lua
            auto luadesc = lua.get!LuaDesc(subPath);
            // Load an external shader file if it was specified
            if (luadesc.shaderFile.length)
            {
                import std.file : readText;
                import std.path : dirName, buildPath;

                try
                {
                    auto fullShaderPath =  buildPath(dirName(path), luadesc.shaderFile);
                    luadesc.shaderFile = fullShaderPath;
                    luadesc.shaderSource = readText(fullShaderPath);
                }
                catch (Exception e)
                {
                    // could not open file or something
                    errorMessage("(%s) could not open shader source file %s",
                            path, luadesc.shaderFile);
                }
            }
            else
            {
                // Embedded shaders
                luadesc.shaderFile = path ~ "(embedded:" ~ subPath ~ ")";
            }
            // combined shader file takes predecence 

            destroy(lua);

            //import std.algorithm.mutation : move;

            // dfmt off
            Desc d = {
                shaderFile: luadesc.shaderFile, 
                blendState : luadesc.blendState.idup,
                barrierBits : luadesc.barrierBits,
                depthStencilState : luadesc.depthStencilState, 
                rasterizerState : luadesc.rasterizerState, 
                layout : luadesc.layout.idup, 
                defines : luadesc.defines.idup, 
                vertexShader : luadesc.shaderSource,
                fragmentShader : luadesc.shaderSource, 
                geometryShader : luadesc.shaderSource, 
                tessControlShader : luadesc.shaderSource, 
                tessEvalShader : luadesc.shaderSource};
	        // dfmt on
            return d;
        }
    }

    this()
    {
    }

    this(Cache cache_, in Desc desc_)
    {
        cache = cache_;
        state.desc = desc_;
    }

    this(Cache cache_, string path) 
    {
        import std.string : lastIndexOf;
        auto split = lastIndexOf(path, "$");
        if (split == -1) {
            assert(false);
        }
        this(cache_, path[0..split], path[split+1..$]);
    }

    this(Cache cache_, string path, string subpath)
    {
        debugMessage("loading pipeline %s, shader %s", path, subpath);
        origPath = path;
        origSubpath = subpath;
        cache = cache_;

        //if (auto cachedDesc = getCachedResource!(Desc)(cache_, path ~ "$" ~ subpath)) {
//
       // }

        state.desc = Desc.fromFile(path, subpath);
    }

    void compile()
    {
        import engine.shader_preprocessor : ShaderSources,
            preprocessMultiShaderSources;

        if (!shouldRecompile) {
            return;
        }

        if (state.vao) 
        {
            state.vao.release();
        }

        if (state.prog) 
        {        
            state.prog.release();
        }

        ShaderSources ss;
        ss.vertexShader.source = state.desc.vertexShader;
        ss.fragmentShader.source = state.desc.fragmentShader;
        ss.geometryShader.source = state.desc.geometryShader;
        ss.tessControlShader.source = state.desc.tessControlShader;
        ss.tessEvalShader.source = state.desc.tessEvalShader;
        ss.vertexShader.path = state.desc.shaderFile;
        ss.fragmentShader.path = state.desc.shaderFile;
        ss.geometryShader.path = state.desc.shaderFile;
        ss.tessControlShader.path = state.desc.shaderFile;
        ss.tessEvalShader.path = state.desc.shaderFile;
        preprocessMultiShaderSources(ss, [], []);
        // create the program
        state.prog = Program.create(Program.Desc(ss.vertexShader.source, ss.fragmentShader.source,
                ss.geometryShader.source, ss.tessControlShader.source, ss.tessEvalShader.source));
        if (!state.prog.getLinkStatus()) {
            errorMessage("Failed to compile program: %s(%s)", origPath, origSubpath);
        }
        // create the VAO
        state.vao = new VertexArray(state.desc.layout);
        debugMessage("desc.layout=%s",state.desc.layout);
        // all done! (now put it in the cache)
        shouldRecompile = false;
        //addCachedResource(cache, origPath ~ "$" ~ origSubpath, state);
    }

    void bind(ref StateGroup sg) 
    {
        compile();
        //debugMessage("sg = %s", sg);
        //debugMessage("desc = %s", desc);
        //debugMessage("prog = %s, vao = %s", prog.object, vao.object);
        if (state.prog && state.prog.valid)
        {
            sg.program = state.prog.object;
            sg.rasterizerState = state.desc.rasterizerState;
            sg.depthStencilState = state.desc.depthStencilState;
            sg.barrierBits = state.desc.barrierBits;
            sg.blendStates = state.desc.blendState.dup;
            sg.vertexArray = state.vao.object;
        }
    }

    string origPath;
    string origSubpath;
    Cache cache;

    struct CachedState 
    { 
        Desc desc;
        // Shared
        Program prog;
        // Not shared
        VertexArray vao;
    }

    CachedState state;
   
    bool shouldRecompile = true;
}

unittest
{
    import std.stdio : writeln;

    auto lua = new LuaState;
    lua.openLibs();
    auto src = `
deferredPass = 
{
	shaderFile = 'DeferredDebug.glsl',
	blendState = {
		[1] = { enabled = true },
		[2] = { enabled = false },
		[3] = { enabled = false },
		[4] = { enabled = false },
		[5] = { enabled = false }},
    layout = {
		{ buffer = 0, type = 8192, size = 2, relativeOffset = 0, normalized = false },
		{ buffer = 0, type = 8192, size = 4, relativeOffset = 8, normalized = true }
	}
}
`;

    /*lua.doString(src);
    auto ppdef = lua.get!PipelineDef("deferredPass");
    assert(ppdef.shaderFile == "DeferredDebug.glsl");
    writeln(ppdef);
    assert(ppdef.blendState.length == 5);*/
}
