module core.camera;

import core.types;

struct Frustum 
{
  float left;
  float right;
  float top;
  float bottom;
  // near clip plane position
  float nearPlane;
  // far clip plane position
  float farPlane;
}

struct Camera {
  // Projection parameters
  // frustum (for culling)
  Frustum frustum;
  // view matrix
  // (World -> View)
  mat4 viewMatrix;
  // inverse view matrix
  // (View -> World)
  mat4 invViewMatrix;
  // projection matrix
  // (View -> clip?)
  mat4 projMatrix;
  // Eye position in world space (camera center)
  vec3 wEye;
}

