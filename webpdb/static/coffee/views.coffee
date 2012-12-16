class StackView
    constructor: (model) ->
        @model = model
        @el = $('#stack')
        @tmpl = _.template($('script.stack-tmpl').html())
        model.subscribe('changed', @update)

    update: =>
        context = {stack: @model.get_stack(), frame_idx: @model.get_frame().idx}
        console.log('StackView:update', context)
        @el.html(@tmpl(context))

class SourceCodeView
    constructor: (model) ->
        @model = model
        @el = $('#source')
        @tmpl = _.template($('script.code-tmpl').html())
        model.subscribe('content_changed', @update_content)
        model.subscribe('lineno_changed', @update_lineno)

    update_content: =>
        console.log('update_content', @model.content)
        console.log(@tmpl({content: @model.content}))
        @el.html(@tmpl({content: @model.content}))
        prettyPrint()
        @update_lineno()

    update_lineno: =>
        console.log('update_lineno:', @model.lineno)
        $('#source .code-highlighter').css('top', "#{@model.lineno * 20 - 7}px")


