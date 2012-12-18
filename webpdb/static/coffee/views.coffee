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
        @tmpl = _.template($('script.variable-tmpl').html())
        @update()
        model.subscribe('changed', @update)
        #model.subscribe('child_added', @attr_added)
        #model.subscribe('child_removed', @attr_removed)

    update: =>
        @self_el.html(@tmpl({variable: @model}))

class SourceCodeView
    constructor: (model) ->
        @model = model
        @el = $('#source')
        @pane_height = @el.height()
        @tmpl = _.template($('script.code-tmpl').html())
        model.subscribe('content_changed', @update_content)
        model.subscribe('lineno_changed', @update_lineno)

    update_content: =>
        console.log('update_content', @model.content)
        @el.html(@tmpl({filename: @model.filename, content: @model.content}))
        prettyPrint()
        @code_height = @el.find('pre.prettyprint').height()
        @update_lineno()

    update_lineno: =>
        console.log('update_lineno:', @model.lineno)
        line_el = @el.find("ol li:nth-child(#{@model.lineno})")
        offset = @el.scrollTop() + line_el.position().top
        console.log('offset', offset)
        $('#source .code-highlighter').css('top', "#{offset}px")
        if offset - @pane_height/2 < 0
            scroll = 0
        else if offset + @pane_height/2 > @code_height
            scroll = @code_height - @pane_height/2
        else
            scroll = offset - @pane_height/2
        @el.scrollTop(scroll)
