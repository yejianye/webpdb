class SourceCodeView
    constructor: (model) ->
        @model = model
        @el = $('#source')
        model.subscribe('content_changed', @update_content)
        model.subscribe('lineno_changed', @update_lineno)

    update_content: =>
        @el.html('')
        @hl_bar = $("<div class='code-highlighter'></div>").appendTo(@el)
        @code_panel = $("<pre class='prettyprint linenums language-python'></pre>").appendTo(@el)
        @code_panel.html(@model.content)
        prettyPrint()
        @update_lineno()

    update_lineno: =>
        @hl_bar.css('top', "#{@model.lineno * 20 - 7}px")


