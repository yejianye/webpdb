#!/usr/bin/env python
from pprint import pprint
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

class CEventDebuggerOutput(rpdb2.CEvent):
    def __init__(self, msg):
        super(CEventDebuggerOutput, self).__init__()
        self.msg = msg

class Debugger(Thread):
    namespace_filter_level = 2
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
        CEventDebuggerOutput: {'msg' : 'msg'},
    }

    def __init__(self, sm):
        super(Debugger, self).__init__()
        self.daemon = True
        self.event_socket = None
        self.stack = None
        self.sm = sm
        sm.set_printer(self.printer)
        sm.register_callback(self.send_event_to_webserver, self.event_types, fSingleUse=False)
        self.files = set()
        self.messages = []

    def run(self):
        self.cmd_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.cmd_server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.cmd_server.bind(config.command_socket_addr)
        self.cmd_server.listen(16)
        bufsize = 4096
        conn, _ = self.cmd_server.accept()
        while True:
            cmd_obj = json.loads(conn.recv(bufsize))
            conn.send(json.dumps(self.execute_command(cmd_obj)))

    def shutdown(self):
        self.cmd_server.close()

    def printer(self, msg):
        print '[DEBUGGER] ', msg
        self.messages.append(msg)
        self.send_event_to_webserver(CEventDebuggerOutput(msg))

    def execute_command(self, cmd_obj):
        print 'execute_command', cmd_obj
        return getattr(self, 'cmd_%s' % cmd_obj['cmd'])(cmd_obj['args'])

    def cmd_next(self, args):
        self.sm.request_next()

    def cmd_step(self, args):
        self.sm.request_step()

    def cmd_return(self, args):
        self.sm.request_return()

    def cmd_go(self, args):
        self.sm.request_go()

    def cmd_stop(self, args):
        self.sm.stop_debuggee()

    def cmd_ls(self, args):
        return list(self.files)

    def cmd_add_breakpoint(self, args):
        self.sm.set_breakpoint(args['filename'], '', args['lineno'], True, '')
        return self.get_breakpoints()

    def cmd_delete_breakpoint(self, args):
        self.sm.delete_breakpoint([args['id']], False)

    def get_breakpoints(self):
        breakpoints = self.sm.get_breakpoints()
        return dict((k, self.serialize_breakpoint(v)) for k, v in breakpoints.iteritems())

    def serialize_breakpoint(self, bp):
        return {
            'id' : bp.m_id,
            'filename' : bp.m_filename,
            'lineno' : bp.m_lineno,
        }

    def cmd_snapshot(self, args):
        snapshot = {
            'breakpoints' : self.get_breakpoints(),
            'messages' : self.messages, 
            'stack' : self.stack,
            'locals' : self.cmd_expr({'expr': 'locals()', 'expand': True}),
            'globals' : self.cmd_expr({'expr': 'globals()', 'expand': True}),
        }
        return snapshot

    def cmd_expr(self, args):
        result = self.sm.get_namespace([(args['expr'], args['expand'])], self.namespace_filter_level, args.get('limit', 128))
        pprint(result)
        return result[0]

    def send_event_to_webserver(self, event):
        if not self.event_socket:
            self.event_socket = socket.create_connection(config.event_socket_addr)
        print 'send event', self.serialize_event(event)
        self.event_socket.send(self.serialize_event(event))
        if isinstance(event, rpdb2.CEventStack):
            self.stack = event.m_stack
            [self.files.add(frame[0]) for frame in event.m_stack['stack']]

    def serialize_event(self, event):
        attrs = self.event_serial[event.__class__] 
        return json.dumps({
            'event_name' : event.__class__.__name__, 
            'event_data' : dict((k, getattr(event, v)) for k,v in attrs.iteritems())
        }) + config.event_eof

def start_client(command_line, fAttach, fchdir, pwd, fAllowUnencrypted, fRemote, host):
    child_pid = os.fork()
    if child_pid:
        sm = rpdb2.CSessionManager(pwd, fAllowUnencrypted, fRemote, host)
        debugger = Debugger(sm)
        debugger.start()
        time.sleep(1.0)
        try:
            if fAttach:
                sm.attach(command_line)
            elif command_line != '':
                sm.launch(fchdir, command_line)
            while True: time.sleep(5.0)
        except KeyboardInterrupt:
            pass
        except:
            sm.report_exception(*sys.exc_info())
            traceback.print_exc()
        finally:
            debugger.shutdown()
            sm.detach()
            sm.shutdown()
            os.wait() # wait the child process, i.e, webserver to gracefully shutdown
            print 'Debugger Shutdown gracefully'
            
    else:
        import webserver
        webserver.main()

if __name__ == '__main__':
    rpdb2.main(start_client, config.title)
