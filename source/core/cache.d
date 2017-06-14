module core.cache;

class CacheObject 
{
    void reload()
    {}

    protected string path;
}


class Cache
{
    void add(CacheObject obj) {
        cacheObjects[obj.path] = obj; 
    }

    T get(T: CacheObject)(string path) const {
        auto obj = path in cacheObjects;
        if (auto o = cast(T)obj) {
            return o;
        }
        return null;
    }

    private CacheObject[string] cacheObjects;
}

class CachedResource(T) : CacheObject
{
    this(T res_, string path_) {
        path = path_;
        resource = res_;
    }

    T resource;
}

T* getCachedResource(T)(Cache cache, string path) {
    return &cache.get!(CachedResource!T)(path).resource;
}

T* addCachedResource(T)(Cache cache, string path, T resource) {
    auto res = new CachedResource!T(resource, path);
    cache.add(res);
    return &res.resource;
}
