from threading import Thread
from Queue import Queue
import bdb
import sys

from webpdb import app

_debugger = None
def debugger():
	global _debugger
	if not _debugger:
		_debugger = Debugger()
	return _debugger

class Debugger(bdb.Bdb):
	def __init__(self, completekey='tab', stdin=None, stdout=None, skip=None):
		self._cmd_queue = Queue()
		bdb.Bdb.__init__(self, skip=skip)

	def web_response(self):
		return str(self.context)		

	def user_line(self, frame):
		self.context = self.canonic(frame.f_code.co_filename)
		cmd = self._cmd_queue.get()
		if cmd == 'QUIT':
			self.set_quit()

	def cmd(self, cmd):
		self._cmd_queue.put(cmd)

def set_trace():
	app_thread = Thread(target=app.run)
	app_thread.daemon = True
	app_thread.start()
	debugger().set_trace()
