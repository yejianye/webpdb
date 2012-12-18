// Generated by CoffeeScript 1.4.0
var AppController, BaseObject, Debugger, EventsDispatcher, PanelController,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

BaseObject = (function() {

  function BaseObject() {
    this.subscribe = __bind(this.subscribe, this);

    this.publish = __bind(this.publish, this);

  }

  BaseObject.prototype.publish = function(event, data) {
    console.log('publish', event, data);
    return $(this).trigger(event, data);
  };

  BaseObject.prototype.subscribe = function(event, handler) {
    return $(this).bind(event, handler);
  };

  return BaseObject;

})();

EventsDispatcher = (function(_super) {

  __extends(EventsDispatcher, _super);

  function EventsDispatcher(url, eof) {
    this.translate_event_name = __bind(this.translate_event_name, this);

    this.on_message = __bind(this.on_message, this);

    this.start = __bind(this.start, this);
    this.event_translation_map = {
      CEventStack: 'stack_update',
      CEventNamespace: 'namespace_update'
    };
    this.ws_url = url;
    this.eof = eof;
  }

  EventsDispatcher.prototype.start = function() {
    this.pending = '';
    this.websocket = new WebSocket(this.ws_url);
    return this.websocket.onmessage = this.on_message;
  };

  EventsDispatcher.prototype.on_message = function(msg) {
    var e, events, _i, _len, _results;
    this.pending += msg.data;
    events = this.pending.split(this.eof);
    this.pending = events.pop();
    events = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = events.length; _i < _len; _i++) {
        e = events[_i];
        _results.push(JSON.parse(e));
      }
      return _results;
    })();
    console.log('on_message', events);
    _results = [];
    for (_i = 0, _len = events.length; _i < _len; _i++) {
      e = events[_i];
      _results.push(this.publish(this.translate_event_name(e.event_name), e.event_data));
    }
    return _results;
  };

  EventsDispatcher.prototype.translate_event_name = function(name) {
    if (name in this.event_translation_map) {
      return this.event_translation_map[name];
    } else {
      return name;
    }
  };

  return EventsDispatcher;

})(BaseObject);

Debugger = (function(_super) {

  __extends(Debugger, _super);

  function Debugger() {
    this.stop = __bind(this.stop, this);

    this.step_out = __bind(this.step_out, this);

    this.step_into = __bind(this.step_into, this);

    this.step_over = __bind(this.step_over, this);

    this["continue"] = __bind(this["continue"], this);

    this.do_command = __bind(this.do_command, this);
    return Debugger.__super__.constructor.apply(this, arguments);
  }

  Debugger.prototype.do_command = function(cmd, args) {
    var params;
    params = args ? {
      args: args
    } : {};
    return $.post("/command/" + cmd, params);
  };

  Debugger.prototype["continue"] = function() {
    return this.do_command('go');
  };

  Debugger.prototype.step_over = function() {
    return this.do_command('next');
  };

  Debugger.prototype.step_into = function() {
    return this.do_command('step');
  };

  Debugger.prototype.step_out = function() {
    return this.do_command('return');
  };

  Debugger.prototype.stop = function() {
    return this.do_command('stop');
  };

  return Debugger;

})(BaseObject);

PanelController = (function(_super) {

  __extends(PanelController, _super);

  function PanelController() {
    this.on_resize = __bind(this.on_resize, this);
    this.pane_container = $('.pane-container');
    this.topbar_height = $('.topbar').height();
    this.on_resize();
    this.pane_container.splitter({
      splitVertical: true,
      resizeTo: window,
      sizeLeft: 400
    });
    $('.right-pane').splitter({
      splitHorizontal: true,
      sizeBottom: 100
    });
    $(window).resize(this.on_resize);
  }

  PanelController.prototype.on_resize = function() {
    var win_height;
    win_height = $(window).height();
    return this.pane_container.height(win_height - this.topbar_height);
  };

  return PanelController;

})(BaseObject);

AppController = (function(_super) {

  __extends(AppController, _super);

  function AppController() {
    this.init = __bind(this.init, this);
    this.init();
  }

  AppController.prototype.init = function() {
    var _this = this;
    return $.get('/init', function(data) {
      _this.dispatcher = new EventsDispatcher("ws://" + window.location.host + "/events", data.event_eof);
      _this["debugger"] = new Debugger();
      _this.panel_controller = new PanelController();
      _this.stack = new Stack(_this.dispatcher);
      _this.stack_view = new StackView(_this.stack);
      _this.locals = new Namespace(_this.dispatcher, 'locals', 'locals()');
      _this.globals = new Namespace(_this.dispatcher, 'globals', 'globals()');
      _this.locals_view = new NamespaceView(_this.locals, $('#locals'));
      _this.globals_view = new NamespaceView(_this.globals, $('#globals'));
      _this.code = new SourceCode(_this.stack);
      _this.code_view = new SourceCodeView(_this.code);
      if (data.snapshot) {
        console.log('snapshot', data.snapshot);
        _this.stack.load(data.snapshot);
        _this.locals.load(data.snapshot);
        _this.globals.load(data.snapshot);
      }
      $('#btn-continue').click(function() {
        return _this["debugger"]["continue"]();
      });
      $('#btn-step-over').click(function() {
        return _this["debugger"].step_over();
      });
      $('#btn-step-into').click(function() {
        return _this["debugger"].step_into();
      });
      $('#btn-step-out').click(function() {
        return _this["debugger"].step_out();
      });
      $('#btn-stop').click(function() {
        return _this["debugger"].stop();
      });
      return _this.dispatcher.start();
    }, 'json');
  };

  return AppController;

})(BaseObject);

$(function() {
  return window.app = new AppController();
});
