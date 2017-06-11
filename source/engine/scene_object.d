module engine.scene_object;

import core.transform;
import core.idtable : ID;
import core.unique;
import core.types;
import core.aabb;
//import engine.mesh : Mesh3D;
import std.container.array;

struct SceneObject 
{
    ID eid;
    Unique!string name;
    SceneObject* parent;
    //Mesh3D* mesh;    // Weak ref!
    //Transform localTransform;
    mat4 worldTransform;
    Array!(SceneObject*) children;
    AABB worldBounds;
    AABB localBounds;
    bool hasWorldBounds;

    void addChild(SceneObject* obj) {

    }

    void removeChild(SceneObject* obj) {

    }

    void calculateWorldBounds() {

    }

    void calculateWorldTransform() {

    }
}

/*class SceneObjectComponents : ComponentManager!SceneObject 
{
    void parent(ID parent, ID child);
}*/
