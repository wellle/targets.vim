function! targets#target#fromArray(array)
    return {
        \ 'sl': a:array[0][0],
        \ 'sc': a:array[0][1],
        \ 'el': a:array[1][0],
        \ 'ec': a:array[1][1],
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
