class SourceCode extends BaseObject
    constructor: (event_dispatcher) ->
        @filename = ''
        @lineno = ''
        @content = ''
        @caches = {}
        @stack = []
        event_dispatcher.subscribe('stack_update', @on_stack_update)

    on_stack_update: (evt, data) =>
        @stack = data.stack.stack
        last_stack = @stack[@stack.length - 1] 
        if @filename != last_stack[0]
            @filename = last_stack[0]
            @fetch_file_content()
        @lineno = last_stack[1]

    fetch_file_content: =>
        if @filename in @caches
            @content = @caches[@filename]
        $.get("/source", {filename: @filename}, (content) => 
            console.log('source code:', content)
            @caches[@filename] = content            
            @content = content
        )

        
