#!/usr/bin/env python
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
        cmd_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        cmd_server.bind(config.command_socket_addr)
        cmd_server.listen(16)
        bufsize = 4096
        conn, _ = cmd_server.accept()
        while True:
            cmd_obj = json.loads(conn.recv(bufsize))
            self.execute_command(cmd_obj)

    def printer(self, msg):
        print '[DEBUGGER] ', msg

    def execute_command(self, cmd_obj):
        print 'execute_command', cmd_obj
        cmd = cmd_obj['cmd']
        if cmd == 'next':
            self.sm.request_next()
        elif cmd == 'stop':
            self.sm.stop_debuggee()

    def send_event_to_webserver(self, event):
        if not self.event_socket:
            self.event_socket = socket.create_connection(config.event_socket_addr)
        self.event_socket.send(self.serialize_event(event))

    def serialize_event(self, event):
        attrs = self.event_serial[event.__class__] 
        return json.dumps({
            'event_name' : event.__class__.__name__, 
            'event_data' : dict((k, getattr(event, v)) for k,v in attrs.iteritems())
        })

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
        try:
            while True: time.sleep(5.0)
        except KeyboardInterrupt:
            sm.detach()
            sm.shutdown()
    else:
        import webserver
        webserver.main()

if __name__ == '__main__':
    rpdb2.main(start_client, config.title)
