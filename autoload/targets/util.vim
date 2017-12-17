" select pair of delimiters around cursor (multi line, no seeking)
" select to the right if cursor is on a delimiter
" cursor  │   ....
" line    │ ' ' b ' '
" matcher │   └───┘
function! targets#util#select(opening, closing, direction, gen)
    if a:direction ==# ''
        return targets#target#withError('select without direction')
    elseif a:direction ==# '>'
        let [sl, sc] = searchpos(a:opening, 'bcW') " search left for opening
        let [el, ec] = searchpos(a:closing, 'W')   " then right for closing
        return targets#target#fromValues(sl, sc, el, ec, a:gen)
    else
        let [el, ec] = searchpos(a:closing, 'cW') " search right for closing
        let [sl, sc] = searchpos(a:opening, 'bW') " then left for opening
        return targets#target#fromValues(sl, sc, el, ec, a:gen)
    endif
endfunction

