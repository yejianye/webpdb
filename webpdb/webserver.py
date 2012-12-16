import os
import sys
import json
import signal
import traceback
from flask import Flask, render_template, request, send_from_directory
import gevent
import gevent.socket as socket
from geventwebsocket.handler import WebSocketHandler
from gevent.pywsgi import WSGIServer
from gevent.queue import JoinableQueue
import config

class SourceFileNotAllowed(Exception):
    pass

class WebServer(Flask):
    def __init__(self, *args, **kwargs):
        super(WebServer, self).__init__(*args, **kwargs)
        print 'Webserver started'
        self.debug = True
        self.cmd_queue = JoinableQueue()
        self.cmd_result_queue = JoinableQueue()
        self.event_queue = JoinableQueue()
        gevent.spawn(self.send_commands_to_debugger)
        gevent.spawn(self.receive_events_from_debugger)

    def do_command(self, cmd, args=''):
        self.cmd_queue.put(json.dumps({
            'cmd' : cmd,
            'args' : args,
        }))
        return json.loads(self.cmd_result_queue.get())

    def send_commands_to_debugger(self):
        print 'start send_commands_to_debugger'
        conn = None
        while True:
            cmd = self.cmd_queue.get()
            if not cmd:
                break
            if not conn:
                conn = socket.create_connection(config.command_socket_addr)
            print 'send command', cmd
            conn.send(cmd)
            self.cmd_result_queue.put(conn.recv(4096))
        
    def receive_events_from_debugger(self):
        print 'start receive_events_from_debugger'
        self.event_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.event_server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.event_server.bind(config.event_socket_addr)
        self.event_server.listen(16)
        conn, _ = self.event_server.accept()
        while True:
            self.event_queue.put(conn.recv(4096))

    def shutdown(self):
        self.event_server.close()

app = WebServer(__name__)

@app.route('/', methods=['GET'])
def index():
    snapshot = app.do_command('snapshot')
    return render_template('index.html', 
        snapshot = snapshot,
        event_eof = config.event_eof,
    )

@app.route('/command/<cmd>', methods=['POST'])
def command(cmd):
    print app.do_command(cmd, request.form.get('args', ''))
    return ''

@app.route('/source', methods=['GET'])
def source_code():
    fname = request.args.get('filename')
    allowed_files = app.do_command('ls')
    if fname not in allowed_files:
        raise SourceFileNotAllowed
    print os.path.dirname(fname), fname
    return send_from_directory(os.path.dirname(fname), os.path.basename(fname))

@app.route('/events')
def events():
    ws = request.environ['wsgi.websocket']
    while True:
        event = app.event_queue.get()
        ws.send(event)
    return  

def main():
    http_server = WSGIServer(config.web_addr, app, handler_class=WebSocketHandler)
    try:
        http_server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        app.shutdown()
        print 'Webserver Shutdown gracefully'


