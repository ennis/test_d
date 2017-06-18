module engine.frame_graph;
import core.imageformat;

class FrameGraph 
{
    static struct DynamicExpression 
    {

    }

    struct Param(T) 
    {
        this(string expr_) {
            expr = expr_;
        }

        string expr;
    }

    static struct InTexture {
        string width = "auto";
        string height = "auto";
        string format = "auto";
    }

    void parseNodeStruct(T)()
    {
       
    }
}

template NodeTy(T)
{
    void getAllVarsInUDA(U)(U v, ref byte[string] varSet)
    {
        foreach (m; __traits(allMembers, U)) 
        {
            if (__traits(getMember, v, m)[0] == '$') {
                varSet[__traits(getMember, v, m)[1..$]] = 1;
            }
        }
    }

    string[] getAllVars() 
    {
        import std.traits : hasUDA, getUDAs;
        byte[string] varSet;
        foreach (m; __traits(allMembers, T)) 
        {
            if (hasUDA!(__traits(getMember, T, m), FrameGraph.InTexture)) {
                getAllVarsInUDA(getUDAs!(__traits(getMember, T, m), FrameGraph.InTexture)[0], varSet);
            }        
        }
        return varSet.keys;
    }

    string synthesizeBody() 
    {
        string outBody;
        string[] vars = getAllVars();
        foreach (v; vars) {
            outBody ~= "int " ~ v ~ ";\n";
        }
        return outBody;
    }

    enum Body = synthesizeBody();

    struct NodeTy
    {
        mixin(Body);
    }
}

unittest 
{
    struct GeometryBuffers
    {
        @(FrameGraph.InTexture("$width", "$height", "D32_SFLOAT"))
        int depth;

        @(FrameGraph.InTexture("$width", "$height", "R16G16_SFLOAT"))
        int normals;

        @(FrameGraph.InTexture("$width", "$height", "R8G8B8A8_UNORM"))
        int diffuse; 

        @(FrameGraph.InTexture("$w2", "$height", "auto"))
        int objectIDs;

        @(FrameGraph.InTexture("$width", "$height", "auto"))
        int velocity;
    } 

    pragma(msg, __traits(allMembers, NodeTy!GeometryBuffers));
}


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