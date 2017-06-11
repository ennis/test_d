module engine.mesh;
import core.types;
import core.vertex;
import gfx.buffer;
import gfx.bind;
import gfx.state_group;
import opengl;

struct Mesh(T) if (isVertexType!(T))
{
    void bind(ref StateGroup sg)
    {
        VertexBuffer(0, vertexBuffer.asSlice(), T.sizeof).bind(sg);
        IndexBuffer(indexBuffer.asSlice(), GL_UNSIGNED_INT).bind(sg);
    }

    Buffer vertexBuffer;
    Buffer indexBuffer;
    int vertexCount;
    int indexCount;
}