import json
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
        self.event_queue = JoinableQueue()
        gevent.spawn(self.send_commands_to_debugger)
        gevent.spawn(self.receive_events_from_debugger)

    def do_command(self, cmd, *args, **kwargs):
        self.cmd_queue.put(json.dumps({
            'cmd' : cmd,
            'args' : args,
            'kwargs' : kwargs,
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
        
    def receive_events_from_debugger(self):
        print 'start receive_events_from_debugger'
        server = socket.socket(AF_INET, SOCK_STREAM)
        server.bind(config.event_socket_addr)
        server.listen(16)
        bufsize = 4096
        conn, _ = server.accept()
        event = ''
        while True:
            new_data = conn.recv(bufsize)
            event += new_data
            if len(new_data) < bufsize: 
                print 'get event', event
                self.event_queue.put(event)
                event = ''

app = WebServer(__name__)

@app.route('/', methods=['GET'])
def index():
    return render_template('index.html')

@app.route('/command/next')
def next():
    app.do_command('next')
    return ''

@app.route('/command/stop')
def stop():
    app.do_command('stop')
    return ''

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

