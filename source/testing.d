module testing;

version (unittest)
{
    import core.dbg;
    import opengl;
    import glfw3;
    import glad.gl.loader;

    void setupOpenGLContext()
    {
        debugMessage("Setting up OpenGL context for unittest...");
	    if (!glfwInit())
		    assert(false, "Application failed to initialize (glfwInit)");
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
        glfwMakeContextCurrent(w);
        enforce(gladLoadGL(), "Could not load opengl functions");
        writefln("OpenGL Version %d.%d loaded", GLVersion.major, GLVersion.minor);
    }
}