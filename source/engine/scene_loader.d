module engine.scene_loader;

import core.cache;
import core.idtable;
import core.vertex;
import core.types;
import engine.scene;
import engine.scene_object;
import engine.mesh;
import derelict.assimp3.assimp;

struct AssimpMeshImporter 
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

    private Mesh3D* importMesh(const(aiScene)* aiscene, int index, Cache cache)
    {
        import std.conv : to;
        auto meshName = path_ ~ ":mesh(" ~ to!string(index) ~ ")";
        auto cachedMesh = getCachedResource!(Mesh3D)(cache, meshName);
        if (!cachedMesh) {
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
            cachedMesh = addCachedResource(cache, meshName, Mesh3D(vertices, indices));
        }
        return cachedMesh;
    }

    void importNode(const(aiScene)* scene, aiNode* node, SceneObject* parent)
    {
        auto id = entities_.createID();
        //auto thisNode = 
    }


}

void importScene(string path, Cache cache, IDTable idTable, SceneObjectComponents sceneObjects)
{


}