module core.transform;

import core.types;
import math.funcs;

struct Transform
{
  vec3 scaling = vec3(1.0f, 1.0f, 1.0f);
  vec3 position = vec3(0.0f, 0.0f, 0.0f);
  quat rotation = quat.identity;

  //  
  mat4 getMatrix() const
  {
    return mat4.translation(position) * cast(mat4)rotation * mat4.scaling(scaling);
  }

  @property mat4 matrix() const {
    return getMatrix();
  }

  // TODO assign matrix property

  // 
  mat3 getNormalMatrix() const
  {
    return mat3.init;
    //return glm::inverseTranspose(mat3{ getMatrix()});
  }

  // application à un point
  vec3 transformPoint(vec3 pos) const
  {
    return vec3.init; // TODO
  }

  // application à un vecteur
  vec3 transformVec(vec3 vector) const
  {
    return vec3.init; // TODO
  }

  // transformation d'une normale
  vec3 transformNormal(vec3 n) const
  {
    return vec3.init; // TODO
  }

  static Transform fromMatrix(ref const(mat4) matrix)
  {
    Transform t;
    t.position = matrix.column(3).xyz;
    t.scaling = vec3(matrix.column(0).length, matrix.column(1).length, matrix.column(2).length);
    mat4 rotMat = matrix;
    rotMat[0][3] = 0.0f;
    rotMat[1][3] = 0.0f;
    rotMat[2][3] = 0.0f;
    rotMat[3][3] = 1.0f;
    rotMat[0] /= vec4(t.scaling, 1.0);
    rotMat[1] /= vec4(t.scaling, 1.0);
    rotMat[2] /= vec4(t.scaling, 1.0);
    t.rotation = cast(quat) rotMat;
    return t;
  }
}
