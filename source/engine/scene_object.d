module engine.scene_object;

import core.transform;
import core.idtable : ID;
import core.unique;
import core.types;
import core.aabb;
import core.dbg;
import engine.mesh : Mesh3D;
import engine.scene;
import std.container.array;

struct SceneObject
{
    ID eid;
    string name;
    SceneObject* parent;
    Mesh3D* mesh; // Weak ref!
    Transform localTransform;
    mat4 worldTransform;
    Array!(SceneObject*) children;
    AABB worldBounds;
    AABB meshBounds;

    ~this()
    {
        if (parent)
        {
            parent.removeChild(&this);
        }
        foreach (c; children[])
        {
            c.parent = null;
        }
    }

    void addChild(SceneObject* obj)
    {
        obj.parent = &this;
        children.insertBack(obj);
    }

    void removeChild(SceneObject* obj)
    {
        import std.algorithm.mutation : remove;
        children.length = remove!(a => a == obj)(children[]).length;
    }

    bool calculateWorldBounds()
    {
        bool hasWorldBounds;
        if (mesh)
        {
            worldBounds = meshBounds.transform(worldTransform);
            hasWorldBounds = true;
        }
        
        foreach (c; children)
        {
            immutable childHasBounds = c.calculateWorldBounds();
            if (childHasBounds)
            {
                if (!hasWorldBounds)
                {
                    worldBounds = c.worldBounds;
                }
                else
                {
                    worldBounds.unionWith(c.worldBounds);
                }
                hasWorldBounds = true;
            }
        }

        debugMessage("obj=%s, world bounds = %s, children=%s", name, worldBounds, children.length);
        return hasWorldBounds;
    }

    void calculateWorldTransform(ref const(mat4) parentTransform)
    {
        mat4 current = parentTransform;
        current *= localTransform.getMatrix();
        worldTransform = current;
        foreach (c; children) {
            c.calculateWorldTransform(current);
        }
    }
}

class SceneObjectComponents : ComponentManager!SceneObject 
{
    void parent(ID parent, ID child)
    {
        auto pparent = parent in components;
        auto pchild = child in components;
        if (pparent && pchild) {
            (*pparent).addChild(*pchild);
        }
    }
}
