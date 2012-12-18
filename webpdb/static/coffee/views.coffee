class StackView
    constructor: (model) ->
        @model = model
        @el = $('#stack')
        #@el.find('.section-header').collapse({toggle:true})
        @el.on('show', => @toggle(true))
        @el.on('hidden', => @toggle(false))
        @tmpl = _.template($('script.stack-tmpl').html())
        model.subscribe('changed', @update)

    toggle: (show) =>
        header_icon = @el.find('.section-header i')
        if show 
            header_icon.removeClass('icon-circle-arrow-right').addClass('icon-circle-arrow-down')
        else
            header_icon.removeClass('icon-circle-arrow-down').addClass('icon-circle-arrow-right')

    update: =>
        stack = @model.get_stack()
        stack = (stack[i] for i in [stack.length - 1 .. 0])
        context = {stack: stack, frame_idx: @model.get_frame().idx}
        console.log('StackView:update', context)
        @el.html(@tmpl(context))

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
