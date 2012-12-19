import os
import sys
import json
import signal
import traceback
from flask import Flask, render_template, request, send_from_directory, jsonify
import gevent
import gevent.socket as socket
from geventwebsocket.handler import WebSocketHandler
from gevent.pywsgi import WSGIServer
from gevent.queue import JoinableQueue
from gevent.event import AsyncResult
import config

static_root = os.path.join(os.path.dirname(__file__), 'static')
class SourceFileNotAllowed(Exception):
    pass

class WebServer(Flask):
    def __init__(self, *args, **kwargs):
        super(WebServer, self).__init__(*args, **kwargs)
        print 'Webserver started'
        self.debug = True
        self.cmd_queue = JoinableQueue()
        self.event_queue = JoinableQueue()
        self.cmd_id = 0
        self.cmd_results = {}
        gevent.spawn(self.send_commands_to_debugger)
        gevent.spawn(self.receive_events_from_debugger)

    def do_command(self, cmd, args=''):
        cmd_id = self.generate_cmd_id()
        self.cmd_results[cmd_id] = AsyncResult()
        self.cmd_queue.put((
            cmd_id, 
            json.dumps({
                'cmd' : cmd,
                'args' : args, 
            }))
        )
        result = self.cmd_results[cmd_id].wait()
        return json.loads(result)

    def generate_cmd_id(self):
        self.cmd_id += 1
        return self.cmd_id

    def send_commands_to_debugger(self):
        print 'start send_commands_to_debugger'
        conn = None
        while True:
            cmd_id, cmd = self.cmd_queue.get()
            if not cmd:
                break
            if not conn:
                conn = socket.create_connection(config.command_socket_addr)
            print 'send command', cmd
            conn.send(cmd)
            result = self.cmd_results.pop(cmd_id)
            result.set(conn.recv(4096))
        
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
    return send_from_directory(static_root, 'index.html')

@app.route('/init', methods=['GET'])
def init():
    return jsonify(
        snapshot = app.do_command('snapshot'),
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

@app.route('/expr', methods=['GET'])
def expr():
    expr = request.args.get('expr')
    expand = bool(request.args.get('expand') == 'true')
    limit = request.args.get('limit')
    return json.dumps(app.do_command('expr', {'expr': expr, 'expand': expand, 'limit': limit}))

@app.route('/vartest')
def vartest():
    result = app.do_command('expr', {'expr': 'locals()', 'expand': True, 'limit': 10})
    result = app.do_command('expr', {'expr': "(locals()['__builtins__'])", 'expand': False, 'limit': 10})
    result = app.do_command('expr', {'expr': "(locals()['__builtins__'])", 'expand': True, 'limit': 10})
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
    except:
        traceback.print_exc()
    finally:
        app.shutdown()
        print 'Webserver Shutdown gracefully'


