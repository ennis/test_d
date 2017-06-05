module core.dbg;
import colorize : fg, color, cwrite, cwritef;

void errorMessage(T...)(string fmt, T args)
{
    cwrite("[ERROR] ".color(fg.red));
    cwritef(fmt, args);
    cwrite("\n");
}

void warningMessage(T...)(string fmt, T args)
{
    cwrite("[WARN ] ".color(fg.yellow));
    cwritef(fmt, args);
    cwrite("\n");
}

void debugMessage(T...)(string fmt, T args)
{
    cwrite("[DEBUG] ".color(fg.light_black));
    cwritef(fmt, args);
    cwrite("\n");
}
