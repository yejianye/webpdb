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
        @lines = []
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
        if @filename of @caches
            @content = @caches[@filename]
            @lines = @content.split('\n')
            @publish('content_changed')
        else
            $.get("/source", {filename: @filename}, (content) => 
                @caches[@filename] = content            
                @fetch_file_content()
            )

    is_blank_line: (lineno) =>
        line = @lines[lineno-1]
        return (not line) or line.trim() == ''

class Variable extends BaseObject
    constructor: (data) ->
        @set_data(data)
        @expand = false
        @children = null
        @name_map = null
        @limit = 10

    refresh:  =>
        $.get('/expr', {expr: @expr, expand: @expand, limit: @limit}, (data) =>
            if not @is_equal(data)
                @set_data(data)
                console.log('var', @name, 'changed')
                @publish('changed')
            if @expand
                @merge_children(data.subnodes)
            console.log('refresh', @)
        , 'json')

    has_child: =>
        return @child_count > 0

    is_equal: (data) =>
        return @repr == data.repr and @type == data.type and @child_count == data.n_subnodes

    set_data: (data) =>
        @name = data.name if data.name
        @expr = data.expr
        @repr = data.repr
        @type = data.type
        @child_count = data.n_subnodes

    merge_children: (children_data) =>
        @children = [] if not @children
        @name_map = {} if not @name_map
        name_set = {}
        for data in children_data
            name_set[data.name] = true
            if data.name of @name_map
                child = @name_map[data.name]
                if not child.is_equal(data)
                    child.set_data(data)
                    child.publish('changed')
                if child.expand
                    child.refresh()
            else
                child = new Variable(data)
                @name_map[data.name] = child
                @children.push(child)
                @publish('child_added', child)
            
        removed = (name for name, child of @name_map when name not of name_set)
        if removed.length > 0
            for name in removed
                @publish('child_removed', @name_map[name])
                delete @name_map[name]
            @children = (child for child in @children when child.name not in removed)

    value: =>
        return if @repr == 'N/A' then '' else @repr

    load_children: =>
        @expand = true 
        @refresh()

    unload_children: =>
        @expand = false
        @children = null
        @name_map = null
        @refresh()

class Namespace extends Variable
    constructor: (event_dispatcher, name, expr) ->
        super({expr: expr, name: name})
        @limit = 256
        @expand = true
        event_dispatcher.subscribe('namespace_update', @refresh)

    load: (snapshot) =>
        @merge_children(snapshot[@name].subnodes)
