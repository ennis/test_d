module gfx.shader;
import opengl;
import gfx.globject;
import core.dbg;

enum ShaderStage
{
  Vertex = 1 << 0,
  Geometry = 1 << 1,
  Fragment = 1 << 2,
  TessControl = 1 << 3,
  TessEval = 1 << 4,
  Compute = 1 << 5
}

class Shader : GLObject
{
  this()
  {
  }

  this(GLenum stage, string src)
  {
    compile(stage, src);
  }

  bool getCompileStatus()
  {
    GLint status = GL_TRUE;
    glGetShaderiv(obj, GL_COMPILE_STATUS, &status);
    return status == GL_TRUE;
  }

  string getCompileLog()
  {
    char[] log;
    GLuint shader = obj;
    GLint logsize = 0;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logsize);
    if (logsize != 0)
    {
      log = new char[logsize];
      glGetShaderInfoLog(shader, logsize, &logsize, log.ptr);
    }
    return log.idup;
  }

  override void release() @nogc {
    if (obj) {
      glDeleteShader(obj);
      obj = 0;
    }
  }

  private void compile(GLenum stage, string source)
  {
    //debugMessage("compile\n%s", source);
    obj = glCreateShader(stage);
    const(char*)[1] shaderSources = [source.ptr];
    glShaderSource(obj, 1, shaderSources.ptr, null);
    glCompileShader(obj);
  }
}

class Program : GLObject
{
  private bool valid_ = false;

  this()
  {
  }

  struct Desc
  {
    string vertexShader;
    string fragmentShader;
    string geometryShader;
    string tessControlShader;
    string tessEvalShader;
  }

  override void release() @nogc {
    if (obj)
    {
      glDeleteProgram(obj);
      obj = 0;
    }
  }

  void attach(Shader s)
  {
    if (!obj)
      obj = glCreateProgram();
    glAttachShader(obj, s.obj);
  }

  bool getLinkStatus()
  {
    GLint status = GL_TRUE;
    glGetProgramiv(obj, GL_LINK_STATUS, &status);
    return status == GL_TRUE;
  }

  string getLinkLog()
  {
    char[] log;
    GLint logsize = 0;
    glGetProgramiv(obj, GL_INFO_LOG_LENGTH, &logsize);
    if (logsize != 0)
    {
      log = new char[logsize];
      glGetProgramInfoLog(obj, logsize, &logsize, log.ptr);
    }
    return log.idup;
  }

  void link() { glLinkProgram(obj); }

  @property bool valid() const 
  {
    return valid_;
  }

  static Program create(Desc sources)
  {
    auto checkedCompile = (string src, GLenum stage) {
      auto s = new Shader(stage, src);
      dumpCompileLog(s, stage);
      return s;
    };

    debugMessage("sources=%s",sources);

    Shader vs, fs, gs, tcs, tes;
    Program prog = new Program();
    vs = checkedCompile(sources.vertexShader, GL_VERTEX_SHADER);
    prog.attach(vs);
    fs = checkedCompile(sources.fragmentShader, GL_FRAGMENT_SHADER);
    prog.attach(fs);
    if (sources.geometryShader.length)
    {
      gs = checkedCompile(sources.geometryShader, GL_GEOMETRY_SHADER);
      prog.attach(gs);
    }
    if (sources.tessEvalShader.length)
    {
      tes = checkedCompile(sources.tessEvalShader, GL_TESS_EVALUATION_SHADER);
      prog.attach(tes);
    }
    if (sources.tessControlShader.length)
    {
      tcs = checkedCompile(sources.tessControlShader, GL_TESS_CONTROL_SHADER);
      prog.attach(tcs);
    }

    prog.link();
    prog.valid_ = prog.getLinkStatus();
    dumpLinkLog(prog);
    return prog;
  }

  static Program createCompute(string computeShader)
  {
    auto s = new Shader(GL_COMPUTE_SHADER, computeShader);
    //dumpCompileLog(s, GL_COMPUTE_SHADER);
    auto p = new Program();
    p.attach(s);
    p.link();
    //dumpLinkLog(this, std::cerr);
    return p;
  }
}

void dumpCompileLog(Shader sh, GLenum stage, string fileHint = "<unknown>")
{
  auto status = sh.getCompileStatus();
  auto log = sh.getCompileLog();
  if (!status)
  {
    errorMessage("===============================================================");
    errorMessage("Shader compilation error (file: %s, stage: %s)", fileHint,
        stage);
    errorMessage("Compilation log follows:\n%s\n", log);
  }
  else if (log.length)
  {
    warningMessage("Shader compilation messages (file: %s, stage: %s)",
        fileHint, stage);
    warningMessage("%s", log);
  }
}

void dumpLinkLog(Program prog, string fileHint = "<unknown>")
{
  auto status = prog.getLinkStatus();
  auto log = prog.getLinkLog();
  if (!status)
  {
    errorMessage("===============================================================");
    errorMessage("Program link error");
    errorMessage("Link log follows:\n%s\n", log);
  }
  else if (log.length)
  {
    warningMessage("Program link messages:");
    warningMessage("%s", log);
  }
}
