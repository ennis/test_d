module engine.scene_loader;

import core.cache;
import core.idtable;
import core.vertex;
import core.types;
import core.dbg;
import engine.scene;
import engine.scene_object;
import engine.mesh;
import derelict.assimp3.assimp;
import core.aabb;

class AssimpSceneImporter 
{
    string path_;
    IDTable entities_;
    SceneObjectComponents sceneObjects_;
    Cache cache_;

    this(string path,
         IDTable entities, 
         SceneObjectComponents sceneObjects,
         Cache cache)
    {
        path_ = path;
        entities_ = entities;
        sceneObjects_ = sceneObjects;
        cache_ = cache;
    }

    private Mesh3D* importMesh(const(aiScene)* aiscene, int index, out AABB aabb)
    {
        import std.conv : to;
        auto meshName = path_ ~ ":mesh(" ~ to!string(index) ~ ")";
        auto cachedMesh = getCachedResource!(Mesh3D)(cache_, meshName);
        if (!cachedMesh) {
            debugMessage("Importing mesh %s", meshName);
            auto aimesh = aiscene.mMeshes[index];
            Vertex3D[] vertices;
            uint[] indices;
            vertices.length = aimesh.mNumVertices;
            indices.length = aimesh.mNumFaces*3;
            for (int i = 0; i < aimesh.mNumVertices; ++i) {
                auto v = aimesh.mVertices[i];
                vertices[i].position = vec3(v.x, v.y, v.z);
            }
            if (aimesh.mNormals) {
                for (int i = 0; i < aimesh.mNumVertices; ++i) {
                    auto v = aimesh.mNormals[i];
                    vertices[i].normal = vec3(v.x, v.y, v.z);
                }
            } 
            if (aimesh.mTangents) {
                for (int i = 0; i < aimesh.mNumVertices; ++i) {
                    auto v = aimesh.mTangents[i];
                    vertices[i].tangent = vec3(v.x, v.y, v.z);
                }
            } 
            if (aimesh.mTextureCoords[0]) {
                for (int i = 0; i < aimesh.mNumVertices; ++i) {
                    auto v = aimesh.mTextureCoords[0][i];
                    vertices[i].texcoords = vec2(v.x, v.y);
                }
            }
            for (int i = 0; i < aimesh.mNumFaces; ++i) {
                indices[i * 3 + 0] = aimesh.mFaces[i].mIndices[0];
                indices[i * 3 + 1] = aimesh.mFaces[i].mIndices[1];
                indices[i * 3 + 2] = aimesh.mFaces[i].mIndices[2];
            }
            aabb = getMeshAABB(vertices);
            debugMessage("AABB=%s", aabb);
            cachedMesh = addCachedResource(cache_, meshName, Mesh3D(vertices, indices));
        }
        return cachedMesh;
    }

    SceneObject* importNode(const(aiScene)* scene, const(aiNode)* node, SceneObject* parent)
    {
        import std.string : fromStringz;
        auto id = entities_.createID();
        SceneObject* thisNode = sceneObjects_.add(id);
        thisNode.eid = id;
        thisNode.name = node.mName.data[0..node.mName.length].idup;
        thisNode.parent = parent;
        debugMessage("Importing node %s", thisNode.name);

        aiVector3D scaling;
        aiVector3D position;
        aiQuaternion rotation;
        aiDecomposeMatrix(&node.mTransformation, &scaling, &rotation, &position);
        thisNode.localTransform.position.x = position.x;
        thisNode.localTransform.position.y = position.y;
        thisNode.localTransform.position.z = position.z;
        thisNode.localTransform.rotation.x = rotation.x;
        thisNode.localTransform.rotation.y = rotation.y;
        thisNode.localTransform.rotation.z = rotation.z;
        thisNode.localTransform.rotation.w = rotation.w;
        thisNode.localTransform.scaling.x = scaling.x;
        thisNode.localTransform.scaling.y = scaling.y;
        thisNode.localTransform.scaling.z = scaling.z;
        if (node.mNumMeshes == 1) {
            thisNode.mesh = importMesh(scene, node.mMeshes[0], thisNode.meshBounds);
        }
        else if (node.mNumMeshes > 1) {
            foreach (meshid; node.mMeshes[0..node.mNumMeshes]) 
            {
                // create sub-objects for the meshes
                auto sub = entities_.createID();
                SceneObject* subObj = sceneObjects_.add(sub);
                subObj.eid = sub;
                subObj.parent = thisNode;
                subObj.mesh = importMesh(scene, meshid, subObj.meshBounds);
                thisNode.children.insertBack(subObj);
            }
        }
        foreach (child; node.mChildren[0..node.mNumChildren]) {
            importNode(scene, child, thisNode);
        }
        if (parent) {
            parent.children.insertBack(thisNode);
        }
        return thisNode;
    }

    SceneObject* importRootNode(SceneObject* parent)
    {
        import std.string : toStringz;
        debugMessage("aiImportFile %s", path_);
        DerelictASSIMP3.load();
        const(aiScene)* scene = aiImportFile(path_.toStringz(), 
            aiProcess_OptimizeMeshes | aiProcess_OptimizeGraph |
            aiProcess_Triangulate | aiProcess_JoinIdenticalVertices |
            aiProcess_CalcTangentSpace | aiProcess_SortByPType);
        if (!scene) {
            import std.string : fromStringz;
            errorMessage("failed to load scene (%s): %s", path_, aiGetErrorString().fromStringz);
            return null;
        }

        auto rootSceneObj = importNode(scene, scene.mRootNode, parent);
        debugMessage("AssimpSceneImporter.importRootNode: imported %s meshes", scene.mNumMeshes);
        return rootSceneObj;        
    }
}

SceneObject* importScene(
        string path, 
        IDTable idTable, 
        SceneObjectComponents sceneObjects,
        SceneObject* parent,
        Cache cache)
{
    import std.string : toStringz;
    debugMessage("idTable=%s,sceneObjects=%s,parent=%s,cache=%s", idTable, sceneObjects, parent, cache);
    AssimpSceneImporter sceneImporter = new AssimpSceneImporter(path, idTable, sceneObjects,  cache);
    auto rootSceneObj = sceneImporter.importRootNode(parent);
    return rootSceneObj;
}