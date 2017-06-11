module gfx.vertex_array;
import gfx.globject;
import gfx.context;
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
public:
  this()
  {}

  this(VertexAttribute[] attribs)
  {}

  void initialize(VertexAttribute[] attribs)
  {
    immutable MaxAttribs = 16; 
    assert(attribs.length < getGfxContext().implementationLimits.max_vertex_attributes);
    glCreateVertexArrays(1, &obj);
    int attribIndex = 0;
    foreach (ref a; attribs) {
      assert(a.slot < MaxAttribs);
      glEnableVertexArrayAttrib(obj, attribIndex);
      glVertexArrayAttribFormat(obj, attribIndex, a.size, a.type, a.normalized, a.relativeOffset);
      glVertexArrayAttribBinding(obj, attribIndex, a.slot);
      ++attribIndex;
    }
  }

  override void release()
  {
    if (obj)
      glDeleteVertexArrays(1, &obj); 
  }
}