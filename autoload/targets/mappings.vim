" maps triggers to sources (per source a list of factory constructor args)
" all of the defaults only use a single source type per trigger, but multiple
" can be combined. see docs for an example
" the first ones are simple mappings, where each trigger has a single args
" dict. for triggers 'b' and 'q' multiple args are used, so they can operate
" on 'any block' or 'any quote' respectively
let s:mappings = {}

function! targets#mappings#extend(mappings)
    call extend(s:mappings, a:mappings)
    " echom 'added mappings ' . string(keys(a:mappings))
endfunction

function! s:addMappings()
    if s:hasLegacySettings()
        " if has any legacy settings (see below), use them
        call s:addLegacyMappings()
    else
        " this is the same result as legacy mappings without custom settings,
        " but rolled out for clarity

        call targets#mappings#extend({
                    \ '(': {'pair': [{'o': '(', 'c': ')'}]},
                    \ ')': {'pair': [{'o': '(', 'c': ')'}]},
                    \ '{': {'pair': [{'o': '{', 'c': '}'}]},
                    \ '}': {'pair': [{'o': '{', 'c': '}'}]},
                    \ 'B': {'pair': [{'o': '{', 'c': '}'}]},
                    \ '[': {'pair': [{'o': '[', 'c': ']'}]},
                    \ ']': {'pair': [{'o': '[', 'c': ']'}]},
                    \ '<': {'pair': [{'o': '<', 'c': '>'}]},
                    \ '>': {'pair': [{'o': '<', 'c': '>'}]},
                    \ })

        call targets#mappings#extend({
                    \ '"': {'quote': [{'d': '"'}]},
                    \ "'": {'quote': [{'d': "'"}]},
                    \ '`': {'quote': [{'d': '`'}]},
                    \ })

        call targets#mappings#extend({
                    \ ',': {'separator': [{'d': ','}]},
                    \ '.': {'separator': [{'d': '.'}]},
                    \ ';': {'separator': [{'d': ';'}]},
                    \ ':': {'separator': [{'d': ':'}]},
                    \ '+': {'separator': [{'d': '+'}]},
                    \ '-': {'separator': [{'d': '-'}]},
                    \ '=': {'separator': [{'d': '='}]},
                    \ '~': {'separator': [{'d': '~'}]},
                    \ '_': {'separator': [{'d': '_'}]},
                    \ '*': {'separator': [{'d': '*'}]},
                    \ '#': {'separator': [{'d': '#'}]},
                    \ '/': {'separator': [{'d': '/'}]},
                    \ '\': {'separator': [{'d': '\'}]},
                    \ '|': {'separator': [{'d': '|'}]},
                    \ '&': {'separator': [{'d': '&'}]},
                    \ '$': {'separator': [{'d': '$'}]},
                    \ })

        call targets#mappings#extend({'t': {'tag': [{}]}})
        call targets#mappings#extend({'a': {'argument': [{'o': '[([]', 'c': '[])]', 's': ','}]}})

        call targets#mappings#extend({'b': {'pair': [{'o':'(', 'c':')'}, {'o':'[', 'c':']'}, {'o':'{', 'c':'}'}]}})
        call targets#mappings#extend({'q': {'quote': [{'d':"'"}, {'d':'"'}, {'d':'`'}]}})
    endif

    " avoid message "No matching autocommands" in some cases
    augroup targets#mappings#silent
        autocmd!
        autocmd User targets#mappings#user silent
        autocmd User targets#mappings#plugin silent
    augroup END

    " allow targets plugins to add their (default mappings)
    doautocmd User targets#mappings#plugin
    " allow users to override those
    doautocmd User targets#mappings#user
endfunction

function! targets#mappings#get(trigger)
    return get(s:mappings, a:trigger, {})
endfunction

function! s:hasLegacySettings()
    return
                \ has_key(g:, 'targets_pairs') ||
                \ has_key(g:, 'targets_quotes') ||
                \ has_key(g:, 'targets_separators') ||
                \ has_key(g:, 'targets_tagTrigger') ||
                \ has_key(g:, 'targets_argTrigger') ||
                \ has_key(g:, 'targets_argOpening') ||
                \ has_key(g:, 'targets_argClosing') ||
                \ has_key(g:, 'targets_argSeparator')
endfunction

function! s:addLegacyMappings()
    call targets#mappings#extend({'b': {'pair': [{'o':'(', 'c':')'}, {'o':'[', 'c':']'}, {'o':'{', 'c':'}'}]}})
    call targets#mappings#extend({'q': {'quote': [{'d':"'"}, {'d':'"'}, {'d':'`'}]}})

    let pairs = get(g:, 'targets_pairs', '() {}B [] <>')
    for pair in split(pairs)
        let config = {'pair': [{'o':pair[0], 'c':pair[1]}]}
        for trigger in split(pair, '\zs')
            call targets#mappings#extend({trigger: config})
        endfor
    endfor

    let quotes = get(g:, 'targets_quotes', '" '' `')
    for quote in split(quotes)
        let config = {'quote': [{'d':quote[0]}]}
        for trigger in split(quote, '\zs')
            call targets#mappings#extend({trigger: config})
        endfor
    endfor

    let separators = get(g:, 'targets_separators', ', . ; : + - = ~ _ * # / \ | & $')
    for separator in split(separators)
        let config = {'separator': [{'d':separator[0]}]}
        for trigger in split(separator, '\zs')
            call targets#mappings#extend({trigger: config})
        endfor
    endfor

    call targets#mappings#extend({get(g:, 'targets_tagTrigger', 't'): {'tag': [{}]}})
    call targets#mappings#extend({get(g:, 'targets_argTrigger', 'a'): {'argument': [{
                \ 'o': get(g:, 'targets_argOpening', '[([]'),
                \ 'c': get(g:, 'targets_argClosing', '[])]'),
                \ 's': get(g:, 'targets_argSeparator', ','),
                \ }]}})
endfunction

call s:addMappings()
