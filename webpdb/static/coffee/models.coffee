class SourceCode extends BaseObject
    constructor: (event_dispatcher) ->
        @filename = ''
        @lineno = ''
        @content = ''
        @caches = {}
        @stack = []
        event_dispatcher.subscribe('stack_update', (evt, data) =>
            @set_stack(data.stack.stack)
        )

    load: (snapshot) =>
        @set_stack(snapshot.stack.stack)
        
    set_stack: (stack) =>
        console.log(stack)
        @stack = stack
        last_stack = @stack[@stack.length - 1] 
        @lineno = last_stack[1]
        if @filename != last_stack[0]
            @filename = last_stack[0]
            @fetch_file_content()
        else
            @publish('lineno_changed')

    fetch_file_content: =>
        if @filename in @caches
            @content = @caches[@filename]
            @publish('content_changed')
        else
            $.get("/source", {filename: @filename}, (content) => 
                console.log('source code:', content)
                @caches[@filename] = content            
                @content = content
                @publish('content_changed')
            )

        
