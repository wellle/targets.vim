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
        \ 'getposS': function('targets#target#getposS'),
        \ 'getposE': function('targets#target#getposE'),
        \ 'cursorS': function('targets#target#cursorS'),
        \ 'cursorE': function('targets#target#cursorE'),
        \ 'invalid': function('targets#target#invalid'),
        \ 'empty': function('targets#target#empty'),
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

" args (mark = '.')
function! targets#target#getposS(...) dict
    let mark = a:0 > 0 ? a:1 : '.'
    let [self.sl, self.sc] = getpos(mark)[1:2]
endfunction

" args (mark = '.')
function! targets#target#getposE(...) dict
    let mark = a:0 > 0 ? a:1 : '.'
    let [self.el, self.ec] = getpos(mark)[1:2]
endfunction

function! targets#target#cursorS() dict
    call cursor(self.s())
endfunction

function! targets#target#cursorE() dict
    call cursor(self.e())
endfunction

function! targets#target#invalid() dict
    if self.sl == 0 || self.el == 0
        return 1
    elseif self.sl < self.el
        return 0
    elseif self.sl > self.el
        return 1
    elseif self.sc == self.ec + 1 " empty match
        return 0
    elseif self.sc > self.ec
        return 1
    else
        return 0
    endif
endfunction

function! targets#target#empty() dict
    if self.sl != self.el
        return 0
    elseif self.sc == self.ec + 1
        return 1
    else
        return 0
    endif
endfunction

function! targets#target#s() dict
    return [self.sl, self.sc]
endfunction

function! targets#target#e() dict
    return [self.el, self.ec]
endfunction
