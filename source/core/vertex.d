module core.vertex;
import core.aabb;
import core.types;

struct Vertex2D {
  vec2 position;
}

struct Vertex2DTex {
  vec2 position;
  vec2 tex;
}

struct Vertex3D {
  vec3 position;
  vec3 normal;
  vec3 tangent;
  vec2 texcoords;
}

enum isVertexType(T) = is(T == struct) && is(typeof(() { T val; val.position; } ()));

AABB getMeshAABB(T)(T[] vertices)
{ 
  static assert (isVertexType(T));
  AABB aabb;
  // init AABB to reasonably unreasonable values
  aabb.xmin = float.max;
  aabb.xmax = -float.max;
  aabb.ymin = float.max;
  aabb.ymax = -float.max;
  aabb.zmin = float.max;
  aabb.zmax = -float.max;
  foreach (v; vertices) 
  {
    auto pos = v.position;
    if (aabb.xmin > pos.x)
      aabb.xmin = pos.x;
    if (aabb.xmax < pos.x)
      aabb.xmax = pos.x;
    if (aabb.ymin > pos.y)
      aabb.ymin = pos.y;
    if (aabb.ymax < pos.y)
      aabb.ymax = pos.y;
    if (aabb.zmin > pos.z)
      aabb.zmin = pos.z;
    if (aabb.zmax < pos.z)
      aabb.zmax = pos.z;
  }
  return aabb;
}