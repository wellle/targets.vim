" maps source to factory constructor, with default sources
" more can be added (before first use) via targets#sources#register()
let s:sources = {
            \ 'pair':      function('targets#sources#pair#new'),
            \ 'quote':     function('targets#sources#quote#new'),
            \ 'separator': function('targets#sources#separator#new'),
            \ 'argument':  function('targets#sources#argument#new'),
            \ 'tag':       function('targets#sources#tag#new'),
            \ }

function! targets#sources#register(source, newFactoryFunc)
    " echom 'registered source: ' . a:source
    call extend(s:sources, {a:source: a:newFactoryFunc}, 'keep')
endfunction

" avoid message "No matching autocommands" in some cases
augroup targetsSourcesRegisterSilent
    autocmd!
    autocmd User targetsSourcesRegister silent
augroup END

" allow targets plugins
doautocmd User targetsSourcesRegister

function! targets#sources#newFactories(trigger)
    let factories = []
    let sources = s:sources(a:trigger)
    for source in keys(sources)
        for args in sources[source]
            if !has_key(s:sources, source)
                echom "targets.vim source '" . source . "' not registered"
                continue
            endif

            let factory = call(s:sources[source], [args])
            let err = targets#factory#init(source, factory)
            if err != ''
                echom "targets.vim source '" . source . "': " . err
                continue
            endif

            call add(factories, factory)
        endfor
    endfor
    return factories
endfunction

function! s:sources(trigger)
    if !exists('s:config')
        " maps triggers to sources (per source a list of factory constructor args)
        let defaultConfig = {
                    \ 'b': { 'pair':  [{'o':'(', 'c':')'}, {'o':'[', 'c':']'}, {'o':'{', 'c':'}'}], },
                    \ 'q': { 'quote': [{'d':"'"}, {'d':'"'}, {'d':'`'}], },
                    \ }

        " we need to assign these like this because Vim 7.3 doesn't seem to like
        " variables as keys in dict definitions like above
        let defaultConfig[g:targets_tagTrigger] = { 'tag': [{}], }
        let defaultConfig[g:targets_argTrigger] = { 'argument': [{
                    \ 'o': get(g:, 'targets_argOpening', '[([]'),
                    \ 'c': get(g:, 'targets_argClosing', '[])]'),
                    \ 's': get(g:, 'targets_argSeparator', ','),
                    \ }], }

        " TODO: document g:targets_config
        let s:config = get(g:, 'targets_config', defaultConfig)

        " TODO: should we still apply those if g:targets_config was set? or
        " only in defaults, like for args and tags?
        " alternatively we could apply those only if at least one of those
        " options have been used by the user. but currently we populate them
        " anyway, so at this point we can't tell anymore. so we would need to
        " stop doing that in plugin/targets.vim, which is currently only being
        " used for legacy behavior (many individual mappings)
        for pair in split(g:targets_pairs)
            let config = {'pair': [{'o':pair[0], 'c':pair[1]}]}
            for trigger in split(pair, '\zs')
                call extend(s:config, {trigger: config}, 'keep')
            endfor
        endfor

        for quote in split(g:targets_quotes)
            let config = {'quote': [{'d':quote[0]}]}
            for trigger in split(quote, '\zs')
                call extend(s:config, {trigger: config}, 'keep')
            endfor
        endfor

        for separator in split(g:targets_separators)
            let config = {'separator': [{'d':separator[0]}]}
            for trigger in split(separator, '\zs')
                call extend(s:config, {trigger: config}, 'keep')
            endfor
        endfor
    endif

    return get(s:config, a:trigger, {})
endfunction
