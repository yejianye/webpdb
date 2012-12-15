import sys
import json
import signal
import traceback
from flask import Flask, render_template, request
import gevent
from socket import AF_INET, SOCK_STREAM
import gevent.socket as socket
from geventwebsocket.handler import WebSocketHandler
from gevent.pywsgi import WSGIServer
from gevent.queue import JoinableQueue
import config

class WebServer(Flask):
    def __init__(self, *args, **kwargs):
        super(WebServer, self).__init__(*args, **kwargs)
        print 'Webserver started'
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
        self.event_server = socket.socket(AF_INET, SOCK_STREAM)
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
    return render_template('index.html', 
        event_eof = config.event_eof,
    )

@app.route('/command/<cmd>', methods=['POST'])
def command(cmd):
    app.do_command(cmd, request.form.get('args', ''))
    return ''

@app.route('/events')
def events():
    ws = request.environ['wsgi.websocket']
    while True:
        event = app.event_queue.get()
        ws.send(event)
    return  

def main():
    def shutdown(signum, frame):
        print 'Webserver shutdown' 
        app.shutdown()
        sys.exit(0)
    signal.signal(signal.SIGINT, shutdown)
    http_server = WSGIServer(config.web_addr, app, handler_class=WebSocketHandler)
    http_server.serve_forever()

