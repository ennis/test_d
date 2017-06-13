module engine.scene;
import core.idtable;

class ComponentManager(T) 
{
    T[ID] components;
    alias components this;
}
