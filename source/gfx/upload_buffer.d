module gfx.upload_buffer;
import gfx.buffer;

import gfm.core.queue;

class UploadBuffer
{
public:
  this()
  {
  }

  this(ulong size)
  {
    buffer = new Buffer(Buffer.Usage.Upload, size);
    mapped_region = buffer.map(0,size);
    fencedRegions = new Queue!FencedRegion(100);
  }

  bool upload(const void* data, ulong size, ulong alignment,
      ulong expirationDate, out Buffer.Slice slice)
  { 
    import core.stdc.string : memcpy;
    if (!allocate(expirationDate, size, alignment, slice))
      return false;
    // copy data
    memcpy(cast(char *)mapped_region + slice.offset, data, size);
    return true;
  }

  bool allocate(ulong expirationDate, ulong size, ulong alignment, out Buffer.Slice slice)
  {
    size_t offset = 0;
    if (!tryAllocateContiguousFreeSpace(expirationDate, size, alignment, offset))
      return false;
    slice.obj = buffer.object;
    slice.offset = offset;
    slice.size = size;
    return true;
  }

  void reclaim(ulong date)
  {
  }

private:
  bool alignOffset(ulong alignment, ulong size, ref ulong ptr, ulong space)
  {
    size_t off = ptr & (alignment - 1);
    if (off > 0)
      off = alignment - off;
    if (space < off || space - off < size)
      return false;
    else
    {
      ptr = ptr + off;
      return true;
    }
  }

  bool tryAllocateContiguousFreeSpace(ulong expirationDate, ulong size,
      ulong alignment, ref ulong alloc_begin)
  {
    // std::lock_guard<std::mutex> guard(mutex);
    assert(size < buffer.size);
    if ((begin_ptr < write_ptr) || ((begin_ptr == write_ptr) && (used == 0)))
    {
      size_t slack_space = buffer.size - write_ptr;
      // try to put the buffer in the slack space at the end
      if (!alignOffset(alignment, size, write_ptr, slack_space))
      {
        // else, try to put it at the beginning (which is always correctly
        // aligned)
        if (size > begin_ptr)
          return false;
        write_ptr = 0;
      }
    }
    else
    { // begin_ptr > write_ptr
      // reclaim space in the middle
      if (alignOffset(alignment, size, write_ptr, begin_ptr - write_ptr))
        alloc_begin = write_ptr;
      else
        return false;
    }

    alloc_begin = write_ptr;
    used += size;
    write_ptr += size;
    fencedRegions.pushBack(FencedRegion(expirationDate, alloc_begin, alloc_begin + size));
    return true;
  }

  struct FencedRegion
  {
    // device fence
    ulong expirationDate;
    // offset to the beginning of the fenced region in the ring buffer
    ulong begin_ptr;
    // offset to the end of the fenced region
    ulong end_ptr;
  }

  Buffer buffer;
  // start of free space in the ring
  ulong write_ptr = 0;
  // end of free space in the ring
  ulong begin_ptr = 0;
  // used space
  ulong used = 0;
  void* mapped_region = null;

  Queue!FencedRegion fencedRegions;
  //std.mutex mutex;
}
