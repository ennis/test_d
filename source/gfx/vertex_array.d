module gfx.vertex_array;
import gfx.globject;
import opengl;

struct VertexAttribute {
  int slot;
  GLenum type;
  int size;
  int relativeOffset;
  bool normalized;
}

class VertexArray : GLObject 
{
  override void release()
  {
    
  }
}