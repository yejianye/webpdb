class Accordion
    constructor: (el) ->
        @el = el
        @el.on('show', => @toggle(true))
        @el.on('hidden', => @toggle(false))

    toggle: (show) =>
        header_icon = @el.find('.section-header i')
        if show 
            header_icon.removeClass('icon-circle-arrow-right').addClass('icon-circle-arrow-down')
        else
            header_icon.removeClass('icon-circle-arrow-down').addClass('icon-circle-arrow-right')

class StackView extends Accordion
    constructor: (model) ->
        super($('#stack'))
        @model = model
        @tmpl = _.template($('script.stack-tmpl').html())
        model.subscribe('changed', @update)

    update: =>
        stack = @model.get_stack()
        stack = (stack[i] for i in [stack.length - 1 .. 0])
        context = {stack: stack, frame_idx: @model.get_frame().idx}
        console.log('StackView:update', context)
        @el.html(@tmpl(context))

class NamespaceView extends Accordion
    constructor: (model, el) ->
        super(el)
        @model = model
        @var_tree = @el.find('ul.variable-list')
        @subviews = {}
        model.subscribe('child_added', @var_added)
        model.subscribe('child_removed', @var_removed)

    var_added: (event, variable) =>
        var_el = $('<li></li>').appendTo(@var_tree)
        var_view = new VariableView(variable, var_el)
        @subviews[variable.name] = var_view

    var_removed: (event, variable) =>
        var_view = @subviews[variable.name]
        var_view.el.remove()
        delete @subviews[variable.name]

class VariableView
    constructor: (model, el) ->
        @el = el
        @model = model
        @self_el = $("<div class='variable'></div>").appendTo(@el)
        @attrs_el = $("<ul class='variable-list'></ul>").appendTo(@el)
        @subviews = {}
        @tmpl = _.template($('script.variable-tmpl').html())
        @update()
        model.subscribe('changed', @update)
        model.subscribe('child_added', (evt, variable) =>
            @add_attr(variable)
        )
        model.subscribe('child_removed', (evt, variable) =>
            @remove_attr(variable)
        )

    update: =>
        @self_el.html(@tmpl({variable: @model}))
        @self_el.find('> i.var-collapse-ctrl').click(@toggle_attrs)

    add_attr: (variable) =>
        attr_el = $('<li></li>').appendTo(@attrs_el)
        attr_view = new VariableView(variable, attr_el)
        @subviews[variable.name] = attr_view
             
    remove_attr: (variable) =>
        attr_view = @subviews[variable.name]
        attr_view.el.remove()
        delete @subviews[variable.name]

    toggle_attrs: =>
        console.log('toggle attrs')
        if not @model.has_child()
            return
        if not @model.expand
            @model.load_children()
        else
            @model.unload_children()
            @subviews = {}
            @attrs_el.html('')
        @update()

class SourceCodeView
    constructor: (model, dbg) ->
        @model = model
        @debugger = dbg
        @el = $('#source')
        @pane_height = @el.height()
        @tmpl = _.template($('script.code-tmpl').html())
        @line_height = 18;
        @top_padding = 8;
        model.subscribe('content_changed', @update_content)
        model.subscribe('lineno_changed', @update_lineno)
        dbg.subscribe('breakpoints_changed', @update_breakpoints)
        dbg.subscribe('breakpoints_removed', @update_breakpoints)


    update_content: =>
        console.log('source code', @model.content)
        @el.html(@tmpl({filename: @model.filename, content: @model.content}))
        prettyPrint()
        @content_el = @el.find('div.content').mousemove(@highlight_line)
        @content_el.mouseout( => @cursor_el.hide())
        @content_el.click(@toggle_breakpoint)
        @cursor_el = @el.find('div.cursor-highlighter')
        @code_height = @el.find('pre.prettyprint').height()
        @update_breakpoints()
        @update_lineno()
        $(window).trigger('resize')

    highlight_line: (evt) =>
        offset = evt.pageY - @content_el.offset().top + @content_el.scrollTop()
        lineno = @lineno_from_offset(offset)
        if @model.is_blank_line(lineno)
            return
        @cursor_lineno = lineno
        @cursor_el.css('top', @line_offset(lineno)).show()

    toggle_breakpoint: =>
        @debugger.toggle_breakpoint(@model.filename, @cursor_lineno)

    update_lineno: =>
        console.log('update_lineno:', @model.lineno)
        offset = @line_offset(@model.lineno)
        $('#source .code-highlighter').css('top', offset)
        if offset - @pane_height/2 < 0
            scroll = 0
        else if offset + @pane_height/2 > @code_height
            scroll = @code_height - @pane_height/2
        else
            scroll = offset - @pane_height/2
        @el.scrollTop(scroll)

    update_breakpoints: =>
        breakpoints = @debugger.get_breakpoints(@model.filename)
        container = @el.find('div.breakpoints')
        container.html('')
        for bp in breakpoints
            bp_el = $("<div class='bp'><i class='icon-exclamation-sign'></i></div>").appendTo(container)
            bp_el.css('top', @line_offset(bp.lineno))

    line_offset: (lineno) =>
        return (lineno - 1) * @line_height + @top_padding

    lineno_from_offset: (offset) =>
        return parseInt((offset - @top_padding) / @line_height) + 1

class ConsoleView
    constructor: (dispatcher) ->
        @el = $('#console > ul.messages')
        dispatcher.subscribe('debugger_output', (evt, data) =>
            @update(data.msg)
        )

    update: (msg) =>
        $("<li>#{msg}</li>").appendTo(@el)

    load: (snapshot) =>
        @update(msg) for msg in snapshot.messages
