class SourceCodeView
    constructor: (model) ->
        @model = model
        @el = $('#source')
        @tmpl = _.template($('script.code-view').html())
        model.subscribe('content_changed', @update_content)
        model.subscribe('lineno_changed', @update_lineno)

    update_content: =>
        console.log('update_content', @model.content)
        console.log(@tmpl({content: @model.content}))
        @el.html(@tmpl({content: @model.content}))
        prettyPrint()
        @update_lineno()

    update_lineno: =>
        $('#source .code-highlighter').css('top', "#{@model.lineno * 20 - 7}px")


