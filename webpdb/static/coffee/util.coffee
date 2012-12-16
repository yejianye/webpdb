util = {
    dirname : (filename) ->
        components = filename.split('/')
        components.pop()
        return components.join('/')

    basename : (filename) ->
        return filename.split('/').pop()

}
