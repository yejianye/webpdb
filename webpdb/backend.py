from Queue import Queue
import bdb

_debugger = None


def debugger():
    global _debugger
    if not _debugger:
        _debugger = Debugger()
    return _debugger


class Debugger(bdb.Bdb):
    def __init__(self, completekey='tab', stdin=None, stdout=None, skip=None):
        self._cmd_queue = Queue()
        self.frame = None
        bdb.Bdb.__init__(self, skip=skip)

    def stack_to_client(self):
        stack, curindex = self.get_stack(self.frame, None)
        result = []
        for frame, lineno in stack:
            result.append({
                'file': frame.f_code.co_filename,
                'lineno': lineno,
                'current': False,
                'desc': self.format_stack_entry((frame, lineno)),
                })
        result[curindex]['current'] = True
        print result
        return result

    def user_line(self, frame):
        self.frame = frame
        cmd = self._cmd_queue.get()
        if cmd == 'QUIT':
            self.set_quit()

    def cmd(self, cmd):
        self._cmd_queue.put(cmd)
