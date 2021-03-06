module core.aabb;
import core.types;

struct AABB
{
  float xmin;
  float ymin;
  float zmin;
  float xmax;
  float ymax;
  float zmax;

  @property float width() const pure nothrow @nogc { return xmax - xmin; }
  @property float height() const pure nothrow @nogc { return ymax - ymin; }
  @property float depth() const pure nothrow @nogc { return zmax - zmin; }

  AABB transform(ref const(mat4) m) const pure nothrow @nogc {
    auto xa = m.column(0) * xmin;
	  auto xb = m.column(0) * xmax;

	  auto ya = m.column(1) * ymin;
	  auto yb = m.column(1) * ymax;

	  auto za = m.column(2) * zmin;
	  auto zb = m.column(2) * zmax;

	  auto vmin = minByElem(xa, xb) + minByElem(ya, yb) + minByElem(za, zb) + m.column(3);
	  auto vmax = maxByElem(xa, xb) + maxByElem(ya, yb) + maxByElem(za, zb) + m.column(3);

	  return AABB(vmin.x, vmin.y, vmin.z, vmax.x, vmax.y, vmax.z);
  }

  ref AABB unionWith(ref const(AABB) other) nothrow @nogc{
    import std.algorithm : min, max;
    xmin = min(xmin, other.xmin);
	  xmax = max(xmax, other.xmax);
	  ymin = min(ymin, other.ymin);
	  ymax = max(ymax, other.ymax);
	  zmin = min(zmin, other.zmin);
	  zmax = max(zmax, other.zmax);
    return this;
  }
}

