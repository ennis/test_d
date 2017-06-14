module engine.scene;
import core.idtable;

// Garbage-collected, for now
class ComponentManager(T) 
{
    import std.typecons : Unique;

    auto add(ID id) 
    {
       auto t = new T;
       components[id] = t;
       return t;
    }

    auto get(ID id) { 
        return id in components;
    }

    T*[ID] components;
    alias components this;
}
