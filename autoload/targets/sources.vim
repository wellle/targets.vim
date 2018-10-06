" maps source to factory constructor, with default sources
" more can be added (before first use) via targets#sources#register()
let s:sources = {
            \ 'pairs':      function('targets#sources#pairs#new'),
            \ 'quotes':     function('targets#sources#quotes#new'),
            \ 'separators': function('targets#sources#separators#new'),
            \ 'arguments':  function('targets#sources#arguments#new'),
            \ 'tags':       function('targets#sources#tags#new'),
            \ }

function! targets#sources#register(source, newFactoryFunc)
    call extend(s:sources, {a:source: a:newFactoryFunc}, 'keep')
endfunction

function! targets#sources#newFactories(trigger)
    let factories = []
    let sources = s:sources(a:trigger)
    for source in keys(sources)
        for args in sources[source]
            call add(factories, call(s:sources[source], [args]))
        endfor
    endfor
    return factories
endfunction

function! s:sources(trigger)
    if !exists('s:config')
        " maps triggers to sources (per source a list of factory constructor args)
        let defaultConfig = {
                    \ 'b': { 'pairs':  [{'o':'(', 'c':')'}, {'o':'[', 'c':']'}, {'o':'{', 'c':'}'}], },
                    \ 'q': { 'quotes': [{'d':"'"}, {'d':'"'}, {'d':'`'}], },
                    \ }

        " we need to assign these like this because Vim 7.3 doesn't seem to like
        " variables as keys in dict definitions like above
        let defaultConfig[g:targets_tagTrigger] = { 'tags': [{}], }
        let defaultConfig[g:targets_argTrigger] = { 'arguments': [{
                    \ 'o': get(g:, 'targets_argOpening', '[([]'),
                    \ 'c': get(g:, 'targets_argClosing', '[])]'),
                    \ 's': get(g:, 'targets_argSeparator', ','),
                    \ }], }

        " TODO: document g:targets_config
        let s:config = get(g:, 'targets_config', defaultConfig)

        " TODO: should we still apply those if g:targets_config was set? or
        " only in defaults, like for args and tags?
        for pair in split(g:targets_pairs)
            let config = {'pairs': [{'o':pair[0], 'c':pair[1]}]}
            for trigger in split(pair, '\zs')
                call extend(s:config, {trigger: config}, 'keep')
            endfor
        endfor

        for quote in split(g:targets_quotes)
            let config = {'quotes': [{'d':quote[0]}]}
            for trigger in split(quote, '\zs')
                call extend(s:config, {trigger: config}, 'keep')
            endfor
        endfor

        for separator in split(g:targets_separators)
            let config = {'separators': [{'d':separator[0]}]}
            for trigger in split(separator, '\zs')
                call extend(s:config, {trigger: config}, 'keep')
            endfor
        endfor
    endif

    return get(s:config, a:trigger, {})
endfunction
