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
        desc = desc_;
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
        desc = Desc.fromFile(path, subpath);
    }

    void compile()
    {
        import engine.shader_preprocessor : ShaderSources,
            preprocessMultiShaderSources;

        ShaderSources ss;
        ss.vertexShader.source = desc.vertexShader;
        ss.fragmentShader.source = desc.fragmentShader;
        ss.geometryShader.source = desc.geometryShader;
        ss.tessControlShader.source = desc.tessControlShader;
        ss.tessEvalShader.source = desc.tessEvalShader;
        ss.vertexShader.path = desc.shaderFile;
        ss.fragmentShader.path = desc.shaderFile;
        ss.geometryShader.path = desc.shaderFile;
        ss.tessControlShader.path = desc.shaderFile;
        ss.tessEvalShader.path = desc.shaderFile;
        preprocessMultiShaderSources(ss, [], []);
        // create the program
        prog = Program.create(Program.Desc(ss.vertexShader.source, ss.fragmentShader.source,
                ss.geometryShader.source, ss.tessControlShader.source, ss.tessEvalShader.source));
        // create the VAO
        vao = new VertexArray(desc.layout);
        // all done!
    }

    void bind(ref StateGroup sg) 
    {
        if (!prog) compile();
        debugMessage("sg = %s", sg);
        debugMessage("desc = %s", desc);
        debugMessage("prog = %s, vao = %s", prog.object, vao.object);
        sg.program = prog.object;
        sg.rasterizerState = desc.rasterizerState;
        sg.depthStencilState = desc.depthStencilState;
        sg.barrierBits = desc.barrierBits;
        sg.blendStates = desc.blendState.dup;
        sg.vertexArray = vao.object;
    }

    string origPath;
    string origSubpath;
    Cache cache;
    Desc desc;
    // Shared
    Program prog;
    // Not shared
    VertexArray vao;
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
