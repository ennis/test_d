import std.stdio;
import std.algorithm;
import std.typecons;
import glfw3;
import opengl;
import core.imageformat;
import gfx.texture;

void main()
{
  immutable int width = 640;
  immutable int height = 480;
  string title = "D GLFW test";

  if (!glfwInit())
    assert(false, "Application failed to initialize (glfwInit)");

  // Create a windowed mode window and its OpenGL context
  glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
  glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 5);
  glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, true);
  glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, true);
  glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
  glfwWindowHint(GLFW_SAMPLES, 8);
  auto w = glfwCreateWindow(width, height, title.ptr, null, null);
  if (!w) {
    glfwTerminate();
    assert(false, "Application failed to initialize (glfwCreateWindow)");
  }
  //glfwSetWindowUserPointer(w, this);
  glfwMakeContextCurrent(w);
  /*if (!gl::sys::LoadFunctions()) {
    glfwTerminate();
    assert(false, "Application failed to initialize (ogl_LoadFunctions)");
  }*/
  glfwSwapInterval(1);
  
  DerelictGL3.load();

  // set event handlers
  /*glfwSetWindowSizeCallback(w_, WindowSizeHandler);
  glfwSetCursorEnterCallback(w_, CursorEnterHandler);
  glfwSetMouseButtonCallback(w_, MouseButtonHandler);
  glfwSetScrollCallback(w_, ScrollHandler);
  glfwSetCursorPosCallback(w_, CursorPosHandler);
  glfwSetCharCallback(w_, CharHandler);
  glfwSetKeyCallback(w_, KeyHandler);*/
  //glfwSetPointerEventCallback(w_, PointerEventHandler);

  while (!glfwWindowShouldClose(w)) {
    glClearColor(0.0, 1.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    glfwSwapBuffers(w);
    glfwPollEvents();
  }

  glfwTerminate();
}
