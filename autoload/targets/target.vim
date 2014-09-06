function! targets#target#fromArray(array)
    return targets#target#fromValues(
        \ a:array[0][0],
        \ a:array[0][1],
        \ a:array[1][0],
        \ a:array[1][1],
        \ )
endfunction

function! targets#target#fromValues(sl, sc, el, ec)
    return {
        \ 'sl': a:sl,
        \ 'sc': a:sc,
        \ 'el': a:el,
        \ 'ec': a:ec,
        \ 'linewise': 0,
        \
        \ 'select': function('targets#target#select'),
        \ 'cursorS': function('targets#target#cursorS'),
        \ 'cursorE': function('targets#target#cursorE'),
        \ 's': function('targets#target#s'),
        \ 'e': function('targets#target#e')
        \ }
endfunction

" visually select the target
function! targets#target#select() dict
    call cursor(self.s())

    if self.linewise
        silent! normal! V
    else
        silent! normal! v
    endif

    call cursor(self.e())
endfunction

function! targets#target#cursorS() dict
    call cursor(self.s())
endfunction

function! targets#target#cursorE() dict
    call cursor(self.e())
endfunction

function! targets#target#s() dict
    return [self.sl, self.sc]
endfunction

function! targets#target#e() dict
    return [self.el, self.ec]
endfunction
