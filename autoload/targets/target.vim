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
        \ 's': function('targets#target#S'),
        \ 'e': function('targets#target#E')
        \ }
endfunction

function! targets#target#S() dict
    return [self.sl, self.sc]
endfunction

function! targets#target#E() dict
    return [self.el, self.ec]
endfunction
