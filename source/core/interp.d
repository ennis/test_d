module core.interp;

import std.conv;

string interp(string str)()
{
	enum State
	{
		normal,
		dollar,
		code,
	}

	auto state = State.normal;

	string buf;
	buf ~= '`';

	foreach(char c; str)
	final switch(state)
	{
	case State.normal:
		if(c == '$')
			// Delay copying the $ until we find out whether it's
			// the start of an escape sequence.
			state = State.dollar;
		else if(c == '`')
			buf ~= "`~\"`\"~`";
		else
			buf ~= c;
		break;

	case State.dollar:
		if(c == '{')
		{
			state = State.code;
			buf ~= "`~_interp_text(";
		}
		else if(c == '$')
			buf ~= '$'; // Copy the previous $
		else
		{
			buf ~= '$'; // Copy the previous $
			buf ~= c;
			state = State.normal;
		}
		break;

	case State.code:
		if(c == '}')
		{
			buf ~= ")~`";
			state = State.normal;
		}
		else
			buf ~= c;
		break;
	}
	
	// Finish up
	final switch(state)
	{
	case State.normal:
		buf ~= '`';
		break;

	case State.dollar:
		buf ~= "$`"; // Copy the previous $
		break;

	case State.code:
		throw new Exception(
			"Interpolated string contains an unterminated expansion. "~
			"You're missing a closing curly brace."
		);
	}

	return buf;
}

string _interp_text(T...)(T args)
{
	static if(T.length == 0)
		return null;
	else
		return std.conv.text(args);
}
