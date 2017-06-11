import std.stdio;
import std.algorithm;
import glfw3;
import opengl;
import core.imageformat;
import core.dbg;
import gfx.texture;
import gfx.context;
import gfx.state_group;
import glad.gl.loader;
import std.exception;
import core.memory;
import core.unique;

import imgui_glfw;
import derelict.imgui.imgui;

struct UIName 
{
	string name;
}

struct UISlider(T)
{
	T minValue;
	T maxValue;
}

struct UIValueFormat
{
	string formatString;
}

alias UISliderFloat = UISlider!float;
alias UISliderInt = UISlider!int;
alias UISliderDouble = UISlider!double;

struct Entity
{
	ulong eid;
	ulong lastUpdate;
	Unique!string name;
}

struct Component 
{
	@UIName("Range")
	@UISliderFloat(0.0f, 1.0f)
	float range;
	
	@UIName("Stuff")
	@UISliderInt(0, 100)
	int stuff;
}

alias I(alias X) = X;

void igGenericGUI(T)(string name, auto ref T val) if (is(T == struct))
{
	import std.traits : hasUDA, getUDAs;

	foreach (m; __traits(allMembers, T)) {
		//pragma(msg, "[GUI struct member: " ~ m ~ "]");
		auto mm = &__traits(getMember, val, m);
		alias MT = typeof(__traits(getMember, val, m));

		string memberName;
		static if (hasUDA!(mm, UIName)) {
			memberName = getUDAs!(mm, UIName)[0].name;
		}
		else {
			memberName = m;
		}

		static if (is(MT == float) || is(MT == double) || is(MT == int)) {
			MT minValue = 0;
			MT maxValue = 1;
			static if (hasUDA!(mm, UISlider!MT)) {
				minValue = getUDAs!(mm, UISlider!MT)[0].minValue;
				maxValue = getUDAs!(mm, UISlider!MT)[0].maxValue;
			}

			static if (is(MT == float)) {
				igSliderFloat(memberName.ptr, mm, minValue, maxValue);
			}
			else static if (is(MT == double)) {
				
			}
			else static if (is(MT == int)) {
				igSliderInt(memberName.ptr, mm, minValue, maxValue);
			}
		}
		else static if (is(MT == string)) {
			char[1000] buf;
			//igInputText(memberName, )
		}
		else static if (is(MT == struct)) {
			//igGenericGUI(memberName, mm);
		}
	}
}



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
	if (!w)
	{
		glfwTerminate();
		assert(false, "Application failed to initialize (glfwCreateWindow)");
	}
	glfwMakeContextCurrent(w);
	enforce(gladLoadGL(), "Could not load opengl functions");
	writefln("OpenGL Version %d.%d loaded", GLVersion.major, GLVersion.minor);

	// set event handlers
	/*glfwSetWindowSizeCallback(w_, WindowSizeHandler);
	glfwSetCursorEnterCallback(w_, CursorEnterHandler);
	glfwSetMouseButtonCallback(w_, MouseButtonHandler);
	glfwSetScrollCallback(w_, ScrollHandler);
	glfwSetCursorPosCallback(w_, CursorPosHandler);
	glfwSetCharCallback(w_, CharHandler);
	glfwSetKeyCallback(w_, KeyHandler);*/
	//glfwSetPointerEventCallback(w_, PointerEventHandler);

	// init gfx context
	auto ctx = new Context(Context.Config(3,3*1024*1024));

	// Create a texture, for fun
	auto tex = Texture.create2D(ImageFormat.R8G8B8A8_UNORM, 16384, 16384, 1, 0,
								Texture.Options.SparseStorage);

	// test allocation
	immutable(long) initial_entities = 60_000;
	immutable(long) turnover = 100;
	import std.conv : to;

	Unique!string str = "test";

	debugMessage("Creating %s entities...", initial_entities);
	auto entities = Unique!(Entity[])(initial_entities);
	// initialize
	foreach (i, ref ent; entities)
	{
		//if (i < 10)
		ent.name = "entity_" ~ to!string(i);
	}
	debugMessage("Done");

	int start_index = 0;

	double t = 0.0;

	bool show_test_window = true;
    float[3] clear_color = [0.3f, 0.4f, 0.8f];

	DerelictImgui.load();
	igImplGlfwGL3_Init(w, true);

	int screenW;
	int screenH;
	glfwGetFramebufferSize(w, &screenW, &screenH);

	static struct Test 
	{
		int a;
		int b;
		float c;
	} 
	Component tt;

	while (!glfwWindowShouldClose(w))
	{
		glfwPollEvents();
		auto tcur = glfwGetTime();
		auto tdiff = tcur - t;
		t = tcur;
		if (1000*tdiff > 1000/60.0+10.0) {
			writefln("SPIKE %s", 1000*tdiff);
		}

		glClearColor(clear_color[0], clear_color[1], clear_color[2], 1.0);
		glClear(GL_COLOR_BUFFER_BIT);

		igImplGlfwGL3_NewFrame();

		ImGuiIO* io = igGetIO();

		{
			static float f = 0.0f;
			igText("Hello, world!");
			igSliderFloat("float", &f, 0.0f, 1.0f);
			igColorEdit3("clear color", clear_color);
			if (igButton("Test Window")) show_test_window = !show_test_window;
			igText("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / io.Framerate, io.Framerate);
			igText("Instantanous %.3f ms/frame (%.1f FPS)", tdiff * 1000.0f, 1.0f / tdiff);
			igGenericGUI("Test reflection", tt);
		}

		if (show_test_window)
		{
		    igSetNextWindowPos(ImVec2(650, 20), ImGuiSetCond_FirstUseEver);
		    igShowTestWindow(&show_test_window);
		}

		//glViewport(0, 0, screenW, screenH);
		igRender();
		glfwSwapBuffers(w);

		// GC pressure test
		// create 'turnover' entities, delete 'turnover' 
		foreach (i, ref ent; entities[start_index .. (start_index + turnover)])
		{
			auto ii = (start_index + i) % initial_entities;
			entities[ii].name = "entity_" ~ to!string(ii);
			//writeln("Name: " ~ entities[i].name);
		}

		start_index++;
		//start_index = start_index % initial_entities;
	}

	igImplGlfwGL3_Shutdown();
	glfwTerminate();
}
