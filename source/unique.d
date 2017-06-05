module unique;

struct Unique(T)
{
    template ArrayType(T : U[], U)
    {
        alias ArrayType = U;
    }

    import core.stdc.stdlib : malloc, calloc;
    import core.stdc.stdlib : free;
    import std.conv : emplace;
    import std.traits : isDynamicArray, ForeachType, Unqual, isCopyable;
    import std.functional : forward;

    static if (isDynamicArray!(T))
    {
        alias ElementType = ArrayType!T;
        ElementType[] data;
    }
    else
    {
        alias ElementType = T;
        ElementType* data;
    }

    static if (isDynamicArray!T)
    {
        static if (isCopyable!ElementType)
        {
            // Construct by copying elements from a slice
            this(T inSlice)
            {
                // allocate memory for the array
                auto ptr = calloc(inSlice.length, ElementType.sizeof);
                // slice of raw elements
                auto tmpdata = (cast(Unqual!(ElementType)*) ptr)[0 .. inSlice.length];
                //pragma(msg, typeof(tmpdata).stringof);
                // copy elements
                foreach (i, ref elem; tmpdata)
                {
                    emplace(&elem, inSlice[i]);
                }
                // init slice with correct qualifiers
                data = cast(T) ptr[0 .. inSlice.length];
            }
        }

        this(Args...)(size_t arraySize, auto ref Args args)
        {
            // allocate memory for the array
            auto ptr = calloc(arraySize, ElementType.sizeof);
            // slice of raw elements
            auto tmpdata = (cast(Unqual!(ElementType)*) ptr)[0 .. arraySize];
            // construct elements
            foreach (ref elem; tmpdata)
            {
                emplace(&elem, args);
            }
            // init slice with correct qualifiers
            data = cast(T) ptr[0 .. arraySize];
        }

        // destroy array
        void destroy()
        {
            if (data)
            {
                foreach (ref elem; data)
                {
                    .destroy(*cast(Unqual!(ElementType)*)&elem); // seems fishy
                }
                free(cast(void*)data.ptr);
                data = null;
            }
        }
    }
    else
    {
        // Ctor
        this(Args...)(Args args)
        {
            // allocate memory for the object
            auto ptr = malloc(T.sizeof);
            data = cast(T) emplace(cast(Unqual!(ElementType)*) ptr, args);
        }

        void destroy()
        {
            if (data)
            {
                .destroy(*cast(Unqual!(ElementType)*) data);
                free(cast(void*)&data);
                data = null;
            }
        }
    }

    ~this()
    {
        destroy();
    }

    static if (isCopyable!ElementType)
    {
        void opAssign(T rhs)
        {
            opAssign(Unique!T(rhs));
        }
    }

    void opAssign(Unique!T rhs)
    {
        destroy();
        static if (isDynamicArray!T)
        {
            // take ownership of the array
            data = rhs.data;
            rhs.data = null;
        }
        else
        {
            // take ownership of the object
            data = rhs.data;
            rhs.data = null;
        }
    }

    alias data this;

    @disable this(this);
}
