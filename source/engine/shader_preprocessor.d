module engine.shader_preprocessor;
import gfx.shader;
import std.regex;
import core.dbg;

struct SourceMapEntry
{
    int index;
    string path;
}

struct IncludeFile
{
    const IncludeFile* parent;
    string path;
}

struct ShaderSource 
{
    string source;
    string path;    // optional
}

struct ShaderSources {
  ShaderSource vertexShader;
  ShaderSource fragmentShader;
  ShaderSource geometryShader;
  ShaderSource tessControlShader;
  ShaderSource tessEvalShader;
  ShaderSource computeShader;
}

void preprocessMultiShaderSources(ref ShaderSources inOutShaderSources,
                    string[] macros, string[] includePaths)
{
  auto preprocessStage = (ref ShaderSource inOutSrc, ShaderStage stage) {
    inOutSrc.source = preprocessShaderSource(
        inOutSrc.source, inOutSrc.path, stage, macros, includePaths);
  };

  preprocessStage(inOutShaderSources.vertexShader, ShaderStage.Vertex);
  preprocessStage(inOutShaderSources.geometryShader, ShaderStage.Geometry);
  preprocessStage(inOutShaderSources.fragmentShader, ShaderStage.Fragment);
  preprocessStage(inOutShaderSources.tessControlShader,
                  ShaderStage.TessControl);
  preprocessStage(inOutShaderSources.tessEvalShader, ShaderStage.TessEval);
  preprocessStage(inOutShaderSources.computeShader, ShaderStage.Compute);
}


auto macroRegex =  ctRegex!(`^(\w+)(?:=(\w*))?$`);

string preprocessShaderSource(string source, string path,
                                   ShaderStage stage, string[] macros,
                                   string[] includePaths) 
{
    import std.conv : to;

  auto thisFile = IncludeFile(null, path);
  string outBody;
  int glsl_version = 0;
  SourceMapEntry[] sourceMap;
  ShaderStage enabledShaderStages = cast(ShaderStage)0;
  preprocessGLSL(outBody, source, glsl_version, enabledShaderStages, &thisFile,
                 sourceMap);
  debugMessage("PP: Enabled stages: %s", enabledShaderStages.stringof);
  // This source does not define a shader of the specified type
  if (!enabledShaderStages & stage) 
  {
    return "";
  }
  if (!glsl_version) {
    warningMessage("No #version directive found while preprocessing: " ~
                   "defaulting to version 3.30");
    glsl_version = 330;
  }
  // Debug infos
  debugMessage("PP: Detected GLSL version: %s", glsl_version);
  debugMessage("PP: Source map:");
  foreach (s; sourceMap) {
    debugMessage("     %s -> %s", s.index, s.path);
  }
  string outHeader;
  int numHeaderLines = 1;
  outHeader ~= "#version " ~ to!string(glsl_version) ~ '\n';
  foreach (macrostr; macros) {
    auto match = matchFirst(macrostr, macroRegex);
    if (match.empty) {
        warningMessage("PP: malformed macro definition? (%s)", macrostr);
    }
    else {
        outHeader ~= "#define " ~ match[1];
        if (match[2].length) {
            outHeader ~= " " ~ match[2];
        } 
        outHeader ~= '\n';
        ++numHeaderLines;
    }
  }

  final switch (stage) {
  case ShaderStage.Vertex:
    outHeader ~= "#define _VERTEX_\n";
    break;
  case ShaderStage.Geometry:
    outHeader ~= "#define _GEOMETRY_\n";
    break;
  case ShaderStage.Fragment:
    outHeader ~= "#define _FRAGMENT_\n";
    break;
  case ShaderStage.TessControl:
    outHeader ~= "#define _TESS_CONTROL_\n";
    break;
  case ShaderStage.TessEval:
    outHeader ~= "#define _TESS_EVAL_\n";
    break;
  case ShaderStage.Compute:
    outHeader ~= "#define _COMPUTE_\n";
    break;
  }
  ++numHeaderLines;

  //
  outHeader ~= "#line " ~ to!string(numHeaderLines) ~ " 0\n";
  return outHeader ~ outBody;
}


auto directivesRegexp = ctRegex!(
        `((?:\s*#include\s+"(.*)"\s*?|\s*#version\s+([0-9]*)\s*?|\s*#pragma\s+(.*)\s*?|(.*))(?:\n|$))`);
auto shaderStagePragmaRegexp = ctRegex!(`(^stages\s*\(\s*(\w+)(?:\s*,\s*(\w+))*\s*\)\s*?$)`);

void preprocessGLSL(ref string ppout, string source, ref int lastSeenVersion,
        ref ShaderStage enabledShaderStages, const IncludeFile* thisFile,
        ref SourceMapEntry[] sourceMap)
{
    import std.path : dirName, buildPath;
    import std.conv : to;
    import std.file : readText;

    int thisFileIndex = cast(int) sourceMap.length;
    sourceMap ~= SourceMapEntry(thisFileIndex, thisFile.path);
    auto dir = dirName(thisFile.path);

    int curLine = 1;
    bool shouldOutputLineDirective = false;

    foreach (m; matchAll(source, directivesRegexp))
    {
        final switch (m.whichPattern())
        {
        case 1: // matched include directive
        {
                auto includePath = m[1];
                // prepend
                includePath = buildPath(dir, includePath);

                string includeText;
                try
                {
                    includeText = readText(includePath);
                    auto includeFile = new IncludeFile(thisFile, includePath);
                    preprocessGLSL(ppout, includeText, lastSeenVersion,
                            enabledShaderStages, includeFile, sourceMap);
                }
                catch (Exception e)
                {
                    // could not open file or something
                    errorMessage("([%s] %s:%s) could not open include file %s",
                            thisFileIndex, thisFile.path, curLine, includePath);
                }

                shouldOutputLineDirective = true;
                curLine++;
                break;
            }

        case 2: // version directive
        {
                auto versionStr = m[2];
                try
                {
                    int versionNum = to!int(versionStr);
                    lastSeenVersion = versionNum;
                }
                catch (Exception e)
                {
                    warningMessage("([%s] %s:%s) malformed #version directive",
                            thisFileIndex, thisFile.path, curLine);
                }
                shouldOutputLineDirective = true;
                curLine++;
                break;
            }
        case 3: // pragma directive
        {
                auto pragmaStagesMatches = matchAll(m[3], shaderStagePragmaRegexp);
                if (!pragmaStagesMatches.empty())
                {
                    foreach (i; 1 .. pragmaStagesMatches.front.length)
                    {
                        auto stageMatch = pragmaStagesMatches.front[i];
                        switch (stageMatch)
                        {
                        case "vertex":
                            enabledShaderStages |= ShaderStage.Vertex;
                            break;
                        case "fragment":
                            enabledShaderStages |= ShaderStage.Fragment;
                            break;
                        case "geometry":
                            enabledShaderStages |= ShaderStage.Geometry;
                            break;
                        case "tess_control":
                            enabledShaderStages |= ShaderStage.TessControl;
                            break;
                        case "tess_eval":
                            enabledShaderStages |= ShaderStage.TessEval;
                            break;
                        case "compute":
                            enabledShaderStages |= ShaderStage.Compute;
                            break;
                        default:
                            warningMessage("([%s] %s:%s) unknown shader stage in #pragma stages(...) directive: {}",
                                    thisFileIndex, thisFile.path, curLine, stageMatch);
                            break;
                        }
                    }
                }
                break;
            }
        case 4: // matched a line
            if (shouldOutputLineDirective)
            {
                ppout ~= "#line " ~ to!string(curLine) ~ " " ~ to!string(thisFileIndex) ~ '\n';
                shouldOutputLineDirective = false;
            }
            ppout ~= m[4];
            curLine++;
            break;
        }
    }

}
