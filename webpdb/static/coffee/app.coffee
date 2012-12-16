class BaseObject
    publish: (event, data) =>
        $(this).trigger(event, data)

    subscribe: (event, handler) =>
        $(this).bind(event, handler)

class EventsDispatcher extends BaseObject
    constructor: (url, eof) ->
        @event_translation_map = {
            CEventStack: 'stack_update',
            CEventNamespace: 'namespace_update',
        }
        @ws_url = url
        @eof = eof

    start: =>
        @pending = ''
        @websocket = new WebSocket(@ws_url)
        @websocket.onmessage = @on_message

    on_message: (msg) =>
        @pending += msg.data
        events = @pending.split(@eof)
        @pending = events.pop()
        events = (JSON.parse(e) for e in events)
        console.log('on_message', events)
        @publish(
            @translate_event_name(e.event_name), e.event_data
        ) for e in events

    translate_event_name: (name) =>
        if name of @event_translation_map
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
        @init()

    init: =>
        $.get('/init', (data) =>
            @dispatcher = new EventsDispatcher("ws://#{ window.location.host }/events", data.event_eof)
            @debugger = new Debugger()
            @stack = new Stack(@dispatcher)
            @stack_view = new StackView(@stack)
            @code = new SourceCode(@stack)
            @code_view = new SourceCodeView(@code)
            $('.pane-container').splitter({
                splitVertical: true,
                resizeTo: window,
                sizeLeft: 400
            });
            $('.right-pane').splitter({
                splitHorizontal: true,
                sizeBottom: 100
            })
            if data.snapshot
                @stack.load(data.snapshot)
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
            @dispatcher.start()
        , 'json')
$ ->
    window.app = new AppController()
