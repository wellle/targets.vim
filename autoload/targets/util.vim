" select pair of delimiters around cursor (multi line, no seeking)
" select to the right if cursor is on a delimiter
" cursor  │   ....
" line    │ ' ' b ' '
" matcher │   └───┘
function! targets#util#select(opening, closing, direction)
    if a:direction ==# ''
        return targets#target#withError('select without direction')
    elseif a:direction ==# '>'
        let [sl, sc] = searchpos(a:opening, 'bcW') " search left for opening
        let [el, ec] = searchpos(a:closing, 'W')   " then right for closing
        return targets#target#fromValues(sl, sc, el, ec)
    else
        let [el, ec] = searchpos(a:closing, 'cW') " search right for closing
        let [sl, sc] = searchpos(a:opening, 'bW') " then left for opening
        return targets#target#fromValues(sl, sc, el, ec)
    endif
endfunction

" search for pattern using flags and optional count
" args (pattern, flags, cnt=1)
function! targets#util#search(pattern, flags, ...)
    let cnt = a:0 >= 1 ? a:1 : 1

    for _ in range(cnt)
        let line = search(a:pattern, a:flags)
        if line == 0 " not enough found
            return targets#util#fail('search')
        endif
    endfor
endfunction

function! targets#util#printpos()
    let line = getline('.')
    let c = col('.')
    let prefix = c == 1 ? '' : line[0 : c-2]
    echom prefix . '→' . line[c-1] . '←' . line[c : ]
endfunction

" return 1 and send a message to targets#util#debug
" args (message, parameters=nil)
function! targets#util#fail(message, ...)
    call targets#util#debug('fail ' . a:message . (a:0 == 0 ? '' : ' ' . string(a:1)))
    return 1
endfunction

function! targets#util#print(...)
    echom string(a:)
endfunction

" useful for debugging
function! targets#util#debug(message)
    " echom a:message
endfunction

