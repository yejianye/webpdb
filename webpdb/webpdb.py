#!/usr/bin/env python
import signal
import sys
import time
import traceback
import os
import rpdb2
import json
import socket
from threading import Thread
import config

class Debugger(Thread):
    event_types = {
        rpdb2.CEventState: {},
        rpdb2.CEventStackFrameChange: {},
        rpdb2.CEventThreads: {},
        rpdb2.CEventNoThreads: {},
        rpdb2.CEventNamespace: {},
        rpdb2.CEventUnhandledException: {},
        rpdb2.CEventConflictingModules: {},
        rpdb2.CEventThreadBroken: {},
        rpdb2.CEventStack: {},
        rpdb2.CEventBreakpoint: {},
        rpdb2.CEventTrap: {},
        rpdb2.CEventEncoding: {},
        rpdb2.CEventSynchronicity: {},
        rpdb2.CEventClearSourceCache: {},
    }

    event_serial = {
        rpdb2.CEventState: {'state' : 'm_state'},
        rpdb2.CEventStackFrameChange: {'frame_index' : 'm_frame_index'},
        rpdb2.CEventThreads: {},
        rpdb2.CEventNoThreads: {},
        rpdb2.CEventNamespace: {},
        rpdb2.CEventUnhandledException: {},
        rpdb2.CEventConflictingModules: {},
        rpdb2.CEventThreadBroken: {},
        rpdb2.CEventStack: {'stack' : 'm_stack'},
        rpdb2.CEventBreakpoint: {},
        rpdb2.CEventTrap: {},
        rpdb2.CEventEncoding: {},
        rpdb2.CEventSynchronicity: {},
        rpdb2.CEventClearSourceCache: {},
    }

    def __init__(self, sm):
        super(Debugger, self).__init__()
        self.daemon = True
        self.event_socket = None
        self.sm = sm
        sm.set_printer(self.printer)
        sm.register_callback(self.send_event_to_webserver, self.event_types, fSingleUse=False)

    def run(self):
        self.cmd_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.cmd_server.bind(config.command_socket_addr)
        self.cmd_server.listen(16)
        bufsize = 4096
        conn, _ = self.cmd_server.accept()
        while True:
            cmd_obj = json.loads(conn.recv(bufsize))
            conn.send(self.execute_command(cmd_obj))

    def shutdown(self):
        self.cmd_server.close()

    def printer(self, msg):
        print '[DEBUGGER] ', msg

    def execute_command(self, cmd_obj):
        print 'execute_command', cmd_obj
        cmd = cmd_obj['cmd']
        if cmd == 'next':
            self.sm.request_next()
        elif cmd == 'step':
            self.sm.request_step()
        elif cmd == 'return':
            self.sm.request_return()
        elif cmd == 'go':
            self.sm.request_go()
        elif cmd == 'stop':
            self.sm.stop_debuggee()
        return 'success'

    def send_event_to_webserver(self, event):
        if not self.event_socket:
            self.event_socket = socket.create_connection(config.event_socket_addr)
        self.event_socket.send(self.serialize_event(event))

    def serialize_event(self, event):
        attrs = self.event_serial[event.__class__] 
        return json.dumps({
            'event_name' : event.__class__.__name__, 
            'event_data' : dict((k, getattr(event, v)) for k,v in attrs.iteritems())
        }) + config.event_eof

def start_client(command_line, fAttach, fchdir, pwd, fAllowUnencrypted, fRemote, host):
    if os.fork():
        sm = rpdb2.CSessionManager(pwd, fAllowUnencrypted, fRemote, host)
        debugger = Debugger(sm)
        debugger.start()
        time.sleep(1.0)
        try:
            if fAttach:
                sm.attach(command_line)
            elif command_line != '':
                sm.launch(fchdir, command_line)
        except:
            sm.report_exception(*sys.exc_info())
            traceback.print_exc()

        def shutdown(signum, frame):
            debugger.shutdown()
            sm.detach()
            sm.shutdown()
            sys.exit(0)

        signal.signal(signal.SIGINT, shutdown)
        while True: time.sleep(5.0)
    else:
        import webserver
        webserver.main()

if __name__ == '__main__':
    rpdb2.main(start_client, config.title)
