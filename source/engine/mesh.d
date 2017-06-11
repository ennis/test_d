module engine.mesh;
import core.types;
import gfx.buffer;

struct Mesh(T) if (isVertexType(T))
{
    Buffer vertexBuffer;
    Buffer indexBuffer;
    int vertexCount;
    int indexCount;
}