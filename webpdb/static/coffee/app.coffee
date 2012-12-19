class BaseObject
    publish: (event, data) =>
        console.log('publish', @, event, data)
        $(this).trigger(event, data)

    subscribe: (event, handler) =>
        $(this).bind(event, handler)

class EventsDispatcher extends BaseObject
    constructor: (url, eof) ->
        @event_translation_map = {
            CEventStack: 'stack_update',
            CEventNamespace: 'namespace_update',
            CEventDebuggerOutput: 'debugger_output',
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

class PaneController extends BaseObject
    constructor: ->
        @pane_container = $('.pane-container')
        @source_pane = $('#source')
        @source_title_height = $('#source > div.title').height()
        @console_pane = $('#console')
        @console_title_height = $('#console > div.title').height()
        @topbar_height = $('.topbar').height()
        @on_resize()
        @pane_container.splitter({
            splitVertical: true,
            resizeTo: window,
            sizeLeft: 400
        })
        $('.right-pane').splitter({
            splitHorizontal: true,
            sizeBottom: 100
        }).resize(@test)
        $(window).resize(@on_right_pane_resize)

    on_right_pane_resize: =>
        source_content = $('#source > div.content')
        source_content.height(@source_pane.height() - @source_title_height)
        source_content.find('> pre').css('min-height', source_content.height())
        $('#console > ul.messages').height(@console_pane.height() - @console_title_height)

    on_resize: =>
        win_height = $(window).height()
        @pane_container.height(win_height - @topbar_height)
        @on_right_pane_resize()

class AppController extends BaseObject
    constructor: ->
        @init()

    init: =>
        $.get('/init', (data) =>
            @dispatcher = new EventsDispatcher("ws://#{ window.location.host }/events", data.event_eof)
            @debugger = new Debugger()
            @stack = new Stack(@dispatcher)
            @stack_view = new StackView(@stack)
            @locals = new Namespace(@dispatcher, 'locals', 'locals()')
            @globals = new Namespace(@dispatcher, 'globals', 'globals()')
            @locals_view = new NamespaceView(@locals, $('#locals'))
            @globals_view = new NamespaceView(@globals, $('#globals'))
            @code = new SourceCode(@stack)
            @code_view = new SourceCodeView(@code)
            @console_view = new ConsoleView(@dispatcher)
            if data.snapshot
                console.log('snapshot', data.snapshot)
                @stack.load(data.snapshot)
                @locals.load(data.snapshot)
                @globals.load(data.snapshot)
                @console_view.load(data.snapshot)
            @pane_controller = new PaneController()
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
