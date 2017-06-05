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

    void get(T: CacheObject)(string path) const {
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

auto getCachedResource(T)(Cache cache, string path) {
    return cache.get!(CachedResource!T)(path).resource;
}

auto addCachedResource(T)(Cache cache, string path, T resource) {
    cache.add(new CachedResource!T(resource, path));
    return resource;
}
