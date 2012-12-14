from webpdb import app
from webpdb import backend

def set_trace():
	app.start_server(new_thread=True)
	backend.debugger().set_trace()
