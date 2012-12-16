class Stack extends BaseObject
    constructor: (event_dispatcher) ->
        @stacks = {}
        @frames = {}
        @current_tid = -1
        event_dispatcher.subscribe('stack_update', (evt, data) =>
            @update(data.stack)
        )

    load: (snapshot) =>
        @update(snapshot.stack)

    update: (data) =>
        stack = (@translate_frame(data.stack[i], i) for i in [0..data.stack.length - 1])
        @frames[data.tid] = stack.length - 1
        @stacks[data.tid] = stack
        if data['current tid']
            @current_tid = data.tid
        @publish('changed')

    get_stack: (tid) =>
        return if tid then @stacks[tid] else @stacks[@current_tid]

    get_frame: (frame_idx, tid) =>
        tid = @current_tid if not tid
        frame_idx = @frames[tid] if not frame_idx
        stack = @get_stack(tid)
        return stack[frame_idx]

    translate_frame: (info, idx) =>
        return {
            idx: idx,
            filename: info[0],
            lineno: info[1],
            function: info[2],
        }


class SourceCode extends BaseObject
    constructor: (stack) ->
        @stack = stack
        @filename = ''
        @lineno = ''
        @content = ''
        @caches = {}
        stack.subscribe('changed', @on_stack_change)

    on_stack_change:  =>
        current_frame = @stack.get_frame()
        @lineno = current_frame.lineno
        if @filename != current_frame.filename
            @filename = current_frame.filename
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
