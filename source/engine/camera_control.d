module engine.camera_control;

import core.camera;
import core.types;
import core.aabb;
import core.dbg;
import engine.scene_object;
import engine.imgui;
import math.funcs;
import std.math;



immutable CamFront = vec3(0.0f, 0.0f, 1.0f);
immutable CamRight = vec3(1.0f, 0.0f, 0.0f);
immutable CamUp = vec3(0.0f, 1.0f, 0.0f);

auto length2(T)(T a)
{
  return dot(a,a);
}

// Shamelessly copied from GLM <glm/gtx/quaternion.inl>
quat rotation(ref const(vec3) orig, ref const(vec3) dest)
{
    alias T = float;
		T cosTheta = dot(orig, dest);
		tvec3!(T) rotationAxis;

		if(cosTheta >= cast(T)1 - T.epsilon)
			return quat();

		if(cosTheta < cast(T) -1 + T.epsilon)
		{
			// special case when vectors in opposite directions :
			// there is no "ideal" rotation axis
			// So guess one; any will do as long as it's perpendicular to start
			// This implementation favors a rotation around the Up axis (Y),
			// since it's often what you want to do.
			rotationAxis = cross(tvec3!(T)(0, 0, 1), orig);
			if(length2(rotationAxis) < T.epsilon) // bad luck, they were parallel, try again!
				rotationAxis = cross(tvec3!(T)(1, 0, 0), orig);

			rotationAxis = rotationAxis.normalized;
			return quat.fromAxis(rotationAxis, cast(T)PI);
		}

		// Implementation from Stan Melax's Game Programming Gems 1 article
		rotationAxis = cross(orig, dest);

		T s = sqrt((cast(T)1 + cosTheta) * cast(T)2);
		T invs = cast(T)1 / s;

		return quat(
			s * cast(T)0.5, 
			rotationAxis.x * invs,
			rotationAxis.y * invs,
			rotationAxis.z * invs);
	}

class CameraController
{
public:
  void zoomIn(float dzoom) { zoomLevel_ += dzoom; }

  void setZoom(float zoom) { zoomLevel_ = zoom; }

  //
  void rotate(float dTheta, float dPhi) {
    theta_ += dTheta;
    phi_ += dPhi;
  }

  // dx, dy in clip space
  void pan(float dx, float dy, float dz) 
  {
	// dx, dy to camera space
	  float panFactor = radius_;
    const vec3 look = toCartesian().normalized();
    const vec3 worldUp = vec3(0.0f, 1.0f, 0.0f);
    const vec3 right = cross(look, worldUp);
    const vec3 up = cross(look, right);
	
	target_ = target_ + (right * dx * panFactor) + (up * dy * panFactor);
	radius_ -= dz*radius_;
  }

  //
  void lookAt(vec3 lookAt) { target_ = lookAt; }
  void lookAt(float x, float y, float z) { target_ = vec3(x, y, z); }
  void lookDistance(float lookDist) { radius_ = lookDist; }
  void setAspectRatio(float aspect_ratio) { aspectRatio_ = aspect_ratio; }
  void setFieldOfView(float fov) { fov_ = fov; }

  void setNearFarPlanes(float nearPlane, float farPlane) {
    nearPlane_ = nearPlane;
    farPlane_ = farPlane;
  }

  //
  Camera getCamera() const  {
    Camera cam;
    cam.viewMatrix = getLookAt();
    cam.invViewMatrix = cam.viewMatrix.inverse;
    cam.projMatrix = mat4.scaling(vec3(zoomLevel_, zoomLevel_, 1.0f)) *
                  mat4.perspective(radians(fov_), aspectRatio_, nearPlane_,
                                   farPlane_);
    cam.wEye = (cam.invViewMatrix * vec4(0.0f, 0.0f, 0.0f, 1.0f)).xyz;
    return cam;
  }

  mat4 getLookAt() const {
    debugMessage("toCartesian=%s", toCartesian());
    debugMessage("arcballRotation=%s, tmpArcballRotation=%s", arcballRotation, tmpArcballRotation);
    return mat4.lookAt(target_ + toCartesian(), target_, CamUp) *
           cast(mat4)(arcballRotation * tmpArcballRotation);
  }

  vec3 toCartesian() const pure nothrow @nogc {
    float x = radius_ * sin(phi_) * sin(theta_);
    float y = radius_ * cos(phi_);
    float z = radius_ * sin(phi_) * cos(theta_);
    return vec3(x, y, z);
  }

  void centerOnObject(ref const(AABB) objectBounds) 
  {
    debugMessage("centerOnObject %s", objectBounds);
    import std.algorithm.comparison : max;
    auto size = max(objectBounds.width, objectBounds.height, objectBounds.depth);
    auto cx = (objectBounds.xmax + objectBounds.xmin) / 2.0f;
    auto cy = (objectBounds.ymax + objectBounds.ymin) / 2.0f;
    auto cz = (objectBounds.zmax + objectBounds.zmin) / 2.0f;
    const float fov = 45.0f;
    float camDist = (0.5f * size) / tan(0.5f * radians(fov));
    lookAt(cx, cy, cz);
    lookDistance(camDist);
    setNearFarPlanes(0.1f * camDist, 10.0f * camDist);
    setFieldOfView(fov);
  	arcballRotation = quat.identity;
    debugMessage("near %s far %s", 0.5f * camDist, 2.0f * camDist);
  }

  void rotateArcball(ref const(mat4) objectToWorld, int screenWidth,
                     int screenHeight, int mouseX, int mouseY) 
    {
    auto viewMat = getLookAt();
    if (mouseX != mouseDownX || mouseY != mouseDownY) {
      vec3 va =
          getArcballVector(screenWidth, screenHeight, mouseDownX, mouseDownY);
      vec3 vb =
          getArcballVector(screenWidth, screenHeight, mouseX, mouseY);
      /*float angle = std::acos(glm::min(1.0f, glm::dot(va, vb)));
      vec3 axis_in_camera_coord = glm::cross(va, vb);
      mat3 camera2world =
          glm::inverse(mat3(viewMat));
      vec3 axis_in_object_coord = camera2object * axis_in_camera_coord;*/
      tmpArcballRotation = rotation(va, vb);        // rotation between va and vb
	}
	else {
		// Commit rotation
		arcballRotation *= tmpArcballRotation;
		tmpArcballRotation = quat.identity;
	}
  }

  vec3 getArcballVector(int sw, int sh, int x, int y) const {
    vec3 P =
        vec3(1.0 * x / cast(float)sw * 2 - 1.0, 1.0 * y / cast(float)sh * 2 - 1.0, 0);
    P.y = -P.y;
    float OP_squared = P.x * P.x + P.y * P.y;
    if (OP_squared <= 1)
      P.z = sqrt(1 - OP_squared);
    else
      P = P.normalized();
    return P;
  }

  enum CameraMode { Idle, Panning, Rotating }

  bool onCameraGUI(int mouseX, int mouseY, int screenW, int screenH,
                           ref Camera inOutCam) 
 {
    bool handled = false;
    // CTRL and SHIFT
    /*bool ctrl_down = igIsKeyDown(KEY_LEFT_CONTROL) ||
                     igIsKeyDown(KEY_RIGHT_CONTROL);
    bool shift_down = igIsKeyDown(KEY_LEFT_SHIFT) ||
                      igIsKeyDown(KEY_RIGHT_SHIFT);*/
    bool ctrl_down = false;
    bool shift_down = false;

    setAspectRatio(cast(float)screenW / cast(float)screenH);

	/*auto sceneObjectComponents =
		scene.getComponentManager!SceneObjectComponents();
	auto selectedObj = sceneObjectComponents.get(selectedObject);

    // Camera focus on object
    if (!ctrl_down && igIsKeyDown(KEY_Z)) {
      AG_DEBUG("Camera focus on {}", selectedObject);
      if (selectedObj)
        focusOnObject(scene, *selectedObj);
      handled = true;
    }

    // Must hold CTRL for camera
    else*/
    if (!ctrl_down) {
      handled = false;
    } else {
      // Camera state machine
      if (igIsMouseDown(0) && mode != CameraMode.Rotating) {
        lastMouseX = mouseDownX = mouseX;
        lastMouseY = mouseDownY = mouseY;
        mode = CameraMode.Rotating;
      } else if (igIsMouseDown(2) && mode != CameraMode.Panning) {
        lastMouseX = mouseDownX = mouseX;
        lastMouseY = mouseDownY = mouseY;
        mode = CameraMode.Panning;
      } else if (!igIsMouseDown(0) && !igIsMouseDown(2)) {
        mode = CameraMode.Idle;
      }

      // Delta w.r.t. last frame
      auto mouseDeltaX = cast(float)(mouseX - lastMouseX);
      auto mouseDeltaY = cast(float)(mouseY - lastMouseY);
      // Delta w.r.t. last click
      auto mouseDragVecX = cast(float)(mouseX - mouseDownX);
      auto mouseDragVecY = cast(float)(mouseY - mouseDownY);

      const auto panFactor = 1.0f / screenW;
      const auto zoomFactor = 0.01f;
      const auto rotateFactor = 0.001f;

      // Rotating & panning
      if (mode == CameraMode.Rotating) {
        if (shift_down) {
          // Shift down => arcball rotation around currently selected object
			/*if (selectedObj)
			{
				debugMessage("Camera rotating %s,%s (arcball around object)", mouseDeltaX,
					mouseDeltaY);
				rotateArcball(selectedObj.worldTransform, screenW, screenH, mouseX, mouseY);
			}*/
        } else {
          debugMessage("Camera rotating %s,%s (camera orientation)", mouseDeltaX,
                   mouseDeltaY);
          rotate(-mouseDeltaX * rotateFactor, -mouseDeltaY * rotateFactor );
        }
      } else if (mode == CameraMode.Panning) {
        debugMessage("Camera panning %s,%s", mouseDeltaX, mouseDeltaY);
        pan(mouseDeltaX * panFactor, -mouseDeltaY * panFactor * aspectRatio_, 0.0f);
      }

      // Scrolling
      float scroll = igGetIO().MouseWheel;
      if (scroll != 0.0f) {
        debugMessage("Camera scrolling %s", scroll);
        pan(0.0f, 0.0f, scroll * zoomFactor);
      }

      igResetMouseDragDelta(0);
      igResetMouseDragDelta(2);
      lastMouseX = mouseX;
      lastMouseY = mouseY;
      handled = true;
    }

    inOutCam = getCamera();
    return handled;
  }

  void focusOnObject(ref SceneObject sceneObject) 
  {
    debugMessage("focusOnObject: %s", sceneObject);
    centerOnObject(sceneObject.worldBounds);
  }

private:
  float fov_ = 45.0f;
  float aspectRatio_ = 1.0f; // should be screenWidth / screenHeight
  float nearPlane_ = 0.001f;
  float farPlane_ = 10.0f;
  float zoomLevel_ = 1.0f;
  float radius_ = 1.0f;
  float theta_ = 0.0f;
  float phi_ = PI_2;
  vec3 target_ = vec3(0.0f, 0.0f, 0.0f);
  quat tmpArcballRotation = quat.identity;
  quat arcballRotation = quat.identity;
  int mouseDownX = 0;
  int mouseDownY = 0;
  int lastMouseX = 0;
  int lastMouseY = 0;
  CameraMode mode;
}

