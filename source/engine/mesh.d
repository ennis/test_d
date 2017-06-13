module engine.mesh;
import core.types;
import core.vertex;
import gfx.buffer;
import gfx.bind;
import gfx.state_group;
import opengl;

struct Mesh(T) if (isVertexType!(T))
{
    this(T[] vertices, uint[] indices)
    {
        vertexBuffer = new Buffer(Buffer.Usage.Default, vertices.length * T.sizeof, vertices.ptr);
        vertexCount = vertices.length;
        indexBuffer = new Buffer(Buffer.Usage.Default, indices.length * uint.sizeof, indices.ptr);
        indexCount = indices.length;
    }

    void bind(ref StateGroup sg)
    {
        VertexBuffer(0, vertexBuffer.asSlice(), T.sizeof).bind(sg);
        IndexBuffer(indexBuffer.asSlice(), GL_UNSIGNED_INT).bind(sg);
    }

    Buffer vertexBuffer;
    Buffer indexBuffer;
    size_t vertexCount;
    size_t indexCount;
}

alias Mesh3D = Mesh!Vertex3D;
