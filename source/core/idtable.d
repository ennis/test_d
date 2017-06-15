module core.idtable;
import std.container.array;

struct ID
{
    ulong id;
    alias id this;
    @property auto index() const { return cast(int) (id & 0xFFFFFFFF); }
    @property auto generation() const { return cast(int) (id >> 32); }
}

class IDTable 
{
public:
    ID createID()
    {
        import core.dbg : debugMessage;
        ID id;
        if (freeIDs.empty()) {
            liveIDs.insertBack(ID(liveIDs.length + (1L << 32)));
            id = liveIDs.back;
        } else {
            id = freeIDs.back;
            freeIDs.removeBack();
        }
        debugMessage("creating ID %s:%s", id.index, id.generation);
        return id;
    }

    void deleteID(ID id)
    {
        import core.dbg : debugMessage;
        immutable idx = id.index;
        // increase generation count
        liveIDs[idx] += 1L << 32;
        // add to free list
        freeIDs.insertBack(liveIDs[idx]);
        debugMessage("deleting ID %s:%s", id.index, id.generation);
    }

    @property auto length() const { return liveIDs.length; }

    bool isValid(ID id) const { 
        immutable idx = id.index;
        return (idx < length) && (id.generation == liveIDs[idx].generation);
    }

private:
    Array!ID liveIDs;
    Array!ID freeIDs;
}
