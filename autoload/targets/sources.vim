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
    let multi = get(s:multis(), a:trigger, {})
    for source in keys(multi)
        for args in multi[source]
            call add(factories, call(s:sources[source], [args]))
        endfor
    endfor
    return factories
endfunction

" TODO: since we use this not only for multis now, rename g:targets_multis?
function! s:multis()
    if exists('s:cached_multis')
        return s:cached_multis
    endif

    " TODO: document this
    let defaultMultis = {
                \ 'b': { 'pairs':  [{'o':'(', 'c':')'}, {'o':'[', 'c':']'}, {'o':'{', 'c':'}'}], },
                \ 'q': { 'quotes': [{'d':"'"}, {'d':'"'}, {'d':'`'}], },
                \ }

    " we need to assign these like this because Vim 7.3 doesn't seem to like
    " variables as keys in dict definitions like above
    let defaultMultis[g:targets_tagTrigger] = { 'tags': [{}], }
    let defaultMultis[g:targets_argTrigger] = { 'arguments': [{
                \ 'o': get(g:, 'targets_argOpening', '[([]'),
                \ 'c': get(g:, 'targets_argClosing', '[])]'),
                \ 's': get(g:, 'targets_argSeparator', ','),
                \ }], }

    let multis = get(g:, 'targets_multis', defaultMultis)

    for pair in split(g:targets_pairs)
        let config = {'pairs': [{'o':pair[0], 'c':pair[1]}]}
        for trigger in split(pair, '\zs')
            call extend(multis, {trigger: config}, 'keep')
        endfor
    endfor

    for quote in split(g:targets_quotes)
        let config = {'quotes': [{'d':quote[0]}]}
        for trigger in split(quote, '\zs')
            call extend(multis, {trigger: config}, 'keep')
        endfor
    endfor

    for separator in split(g:targets_separators)
        let config = {'separators': [{'d':separator[0]}]}
        for trigger in split(separator, '\zs')
            call extend(multis, {trigger: config}, 'keep')
        endfor
    endfor

    let s:cached_multis = multis
    return multis
endfunction
