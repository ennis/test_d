module gfx.fence;
import opengl;
import gfx.globject;
import gfm.core.queue;

class Fence
{
    enum WaitTimeout = 2000000000; // in nanoseconds

    void signal(ulong value)
    {
        //AG_FRAME_TRACE("this={}, value={}", (const void*)this, value);
        auto sync = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0);
        syncPoints.pushBack(SyncPoint(sync, value));
    }

    GLenum advance(ulong timeout)
    {
        auto targetSyncPoint = syncPoints.front;
        auto waitResult = glClientWaitSync(targetSyncPoint.sync,
                GL_SYNC_FLUSH_COMMANDS_BIT, timeout);
        if (waitResult == GL_CONDITION_SATISFIED || waitResult == GL_ALREADY_SIGNALED)
        {
            currentValue_ = targetSyncPoint.targetValue;
            //AG_FRAME_TRACE("this={}, current_value={}", cast(const void*)this, current_value);
            glDeleteSync(targetSyncPoint.sync);
            syncPoints.popFront();
        }
        else if (waitResult == GL_WAIT_FAILED)
        {
            assert(false, "Wait failed while waiting for fence");
        }
        return waitResult;
    }

    void wait(ulong value)
    {
        //AG_FRAME_TRACE("this={}, value={}", cast(const void * ) this, value);
        while (currentValue < value)
        {
            auto waitResult = advance(WaitTimeout);
            if (waitResult == GL_TIMEOUT_EXPIRED)
            {
                assert(false, "Timeout expired while waiting for fence");
            }
        }
    }

    @property ulong currentValue()
    {
        while (!syncPoints.length)
        {
            auto waitResult = advance(0);
            if (waitResult == GL_TIMEOUT_EXPIRED)
                break;
        }
        return currentValue_;
    }

    ~this()
    {
        foreach (ref s; syncPoints)
        {
            glDeleteSync(s.sync);
        }
    }

    static struct SyncPoint
    {
        GLsync sync;
        ulong targetValue;
    }

private:
    ulong currentValue_;
    Queue!SyncPoint syncPoints;
}
