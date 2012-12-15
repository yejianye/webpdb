class BaseObject
    publish: (event, data) =>
        $(this).trigger(event, data)

    subscribe: (event, handler) =>
        $(this).bind(event, handler)

class EventsDispatcher extends BaseObject
    constructor: (url) ->
        @event_translation_map = {
            CEventStack: 'stack_update',
            CEventNamespace: 'namespace_update',
        }
        @websocket = new WebSocket(url)
        @websocket.onmessage = @on_message
        @pending = ''

    on_message: (msg) =>
        @pending += msg.data
        events = @pending.split(EVENT_EOF)
        @pending = events.pop()
        events = (JSON.parse(e) for e in events)
        console.log('on_message', events)
        @publish(
            @translate_event_name(e.event_name, e.event_data)
        ) for e in events

    translate_event_name: (name) =>
        if name in @event_translation_map
            return @event_translation_map[name]
        else
            return name

class Debugger extends BaseObject
    do_command: (cmd, args) =>
        params = if args then { args: args } else {}
        $.post("/command/#{cmd}", params)
    continue: => @do_command('go')
    step_over: => @do_command('next')
    step_into: => @do_command('step')
    step_out: => @do_command('return')
    stop: => @do_command('stop')

class AppController extends BaseObject
    constructor: ->
        @dispatcher = new EventsDispatcher("ws://#{ window.location.host }/events")
        @debugger = new Debugger()
        $('#btn-continue').click( => 
            @debugger.continue()
        )
        $('#btn-step-over').click( =>
            @debugger.step_over()
        )
        $('#btn-step-into').click( =>
            @debugger.step_into()
        )
        $('#btn-step-out').click( =>
            @debugger.step_out()
        )
        $('#btn-stop').click( =>
            @debugger.stop()
        )

$ ->
    window.app = new AppController()
