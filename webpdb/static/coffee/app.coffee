class BaseObject
    publish: (event, data) =>
        $(this).trigger(event, data)

    subscribe: (event, handler) =>
        $(this).bind(event, handler)

class EventsDispatcher extends BaseObject
    constructor: (url) ->
        @websocket = new WebSocket(url)
        @websocket.onmessage = @on_message

    on_message: (msg) =>
        msg = JSON.parse(msg)
        console.log('on_message', msg)
        $.publish(msg.event_name, msg.event_data)

$ ->
    #window.dispatcher = new EventsDispatcher("ws://localhost:6677/events")
