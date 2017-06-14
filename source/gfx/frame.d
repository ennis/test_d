module gfx.frame;

import gfx.buffer;
import gfx.context;
import gfx.upload_buffer;

auto uploadFrameData(T)(ref T data, size_t alignment = -1) 
{
    Context ctx = getGfxContext();
    UploadBuffer uploadBuffer = ctx.uploadBuffer;
    // First, reclaim data from frame N-<max-frames-in-flight> (guaranteed to be done)
    uploadBuffer.reclaim(ctx.currentFrameIndex - ctx.config.maxFramesInFlight + 1);
    auto expirationDate = ctx.currentFrameIndex+1;

    const(void)* ptr;
    size_t len;

    static if (is(T : U[], U)) {
        static assert(is(U == struct));
        ptr = data.ptr;
        len = data.length * U.sizeof;

    }
    else {
        // Uploading a reference type makes no sense
        // (also: check inside the struct for pointers?)
        static assert(is(T == struct));
        ptr = &data;
        len = T.sizeof;
    }

    if (alignment == -1) {
        alignment = ctx.implementationLimits.uniform_buffer_alignment;
    }

    Buffer.Slice slice;
    if (!uploadBuffer.upload(ptr, len, alignment, expirationDate, slice)) {
        assert(false, "Upload buffer is full");
    }
    return slice;
}
