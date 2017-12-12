" TODO: add source, from gen, like PN(3, might help for debugging

function! targets#target#new(sl, sc, el, ec, gen, error)
    return {
        \ 'error': a:error,
        \ 'sl':    a:sl,
        \ 'sc':    a:sc,
        \ 'el':    a:el,
        \ 'ec':    a:ec,
        \ 'gen':   a:gen,
        \ 'linewise': 0,
        \
        \ 'copy': function('targets#target#copy'),
        \ 'equal': function('targets#target#equal'),
        \ 'setS': function('targets#target#setS'),
        \ 'setE': function('targets#target#setE'),
        \ 's': function('targets#target#s'),
        \ 'e': function('targets#target#e'),
        \ 'searchposS': function('targets#target#searchposS'),
        \ 'searchposE': function('targets#target#searchposE'),
        \ 'getcharS': function('targets#target#getcharS'),
        \ 'getcharE': function('targets#target#getcharE'),
        \ 'getposS': function('targets#target#getposS'),
        \ 'getposE': function('targets#target#getposE'),
        \ 'cursorS': function('targets#target#cursorS'),
        \ 'cursorE': function('targets#target#cursorE'),
        \ 'state': function('targets#target#state'),
        \ 'range': function('targets#target#range'),
        \ 'select': function('targets#target#select'),
        \ 'string': function('targets#target#string')
        \ }
endfunction

function! targets#target#fromValues(sl, sc, el, ec, gen)
    if a:sl == 0 || a:sc == 0 || a:el == 0 || a:ec == 0
        return targets#target#withError("zero found")
    endif
    return targets#target#new(a:sl, a:sc, a:el, a:ec, a:gen, '')
endfunction

function! targets#target#fromVisualSelection(selection)
    let [sl, sc] = getpos("'<")[1:2]
    let [el, ec] = getpos("'>")[1:2]

    if a:selection ==# 'exclusive'
        let ec -= 1
    endif

    return targets#target#fromValues(sl, sc, el, ec, 0)
endfunction

function! targets#target#withError(error)
    return targets#target#new(0, 0, 0, 0, 0, a:error)
endfunction

function! targets#target#copy() dict
    return targets#target#fromValues(self.sl, self.sc, self.el, self.ec, self.gen)
endfunction

function! targets#target#equal(t) dict
    return
                \ self.error    == a:t.error &&
                \ self.sl       == a:t.sl    &&
                \ self.sc       == a:t.sc    &&
                \ self.el       == a:t.el    &&
                \ self.ec       == a:t.ec    &&
                \ self.linewise == a:t.linewise
endfunction

function! targets#target#setS(line, column) dict
    let [self.sl, self.sc] = [a:line, a:column]
endfunction

function! targets#target#setE(line, column) dict
    let [self.el, self.ec] = [a:line, a:column]
endfunction

function! targets#target#s() dict
    return [self.sl, self.sc]
endfunction

function! targets#target#e() dict
    return [self.el, self.ec]
endfunction

function! targets#target#searchposS(...) dict
    let pattern = a:1
    let flags = a:0 > 1 ? a:2 : ''
    let stopline = a:0 > 2 ? a:3 : 0
    let [self.sl, self.sc] = searchpos(pattern, flags, stopline)
endfunction

function! targets#target#searchposE(...) dict
    let pattern = a:1
    let flags = a:0 > 1 ? a:2 : ''
    let stopline = a:0 > 2 ? a:3 : 0
    let [self.el, self.ec] = searchpos(pattern, flags, stopline)
endfunction

function! targets#target#getcharS() dict
    return getline(self.sl)[self.sc-1]
endfunction

function! targets#target#getcharE() dict
    return getline(self.el)[self.ec-1]
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

function! targets#target#state() dict
    if self.error != ''
        return targets#state#invalid()
    endif
    if self.sl == 0 || self.el == 0
        return targets#state#invalid()
    elseif self.sl < self.el
        return targets#state#nonempty()
    elseif self.sl > self.el
        return targets#state#invalid()
    elseif self.sc == self.ec + 1
        return targets#state#empty()
    elseif self.sc > self.ec
        return targets#state#invalid()
    else
        return targets#state#nonempty()
    endif
endfunction

" returns range characters and min distance to cursor (lines; characters)
function! targets#target#range(context) dict
    if self.error != ''
        return ['', 1/0, 1/0]
    endif

    let [positionS, linesS, charsS] = s:position(self.sl, self.sc, a:context)
    let [positionE, linesE, charsE] = s:position(self.el, self.ec, a:context)
    return [positionS . positionE, min([linesS, linesE]), min([charsS, charsE])]
endfunction

" returns position character and distances to cursor (lines; characters)
function! s:position(line, column, context)
    let [cursorLine, cursorColumn] = a:context.oldpos[1:2]

    if a:line == cursorLine " cursor line
        if a:column == cursorColumn " same column
            return ['c', 0, 0]
        elseif a:column < cursorColumn " left of cursor
            return ['l', 0, cursorColumn - a:column]
        else " a:column > cursorColumn " right of cursor
            return ['r', 0, a:column - cursorColumn]
        endif

    elseif a:line < cursorLine
        if a:line >= a:context.minline " above on screen
            return ['a', cursorLine - a:line, -a:column]
        else " above off screen
            return ['A', cursorLine - a:line, -a:column]
        endif

    else " a:line > cursorLine
        if a:line <= a:context.maxline " below on screen
            return ['b', a:line - cursorLine, a:column]
        else " below off screen
            return ['B', a:line - cursorLine, a:column]
        endif
    endif
endfunction

" visually select the target
function! targets#target#select() dict
    call self.cursorS()

    if self.linewise
        silent! normal! V
    else
        silent! normal! v
    endif

    call self.cursorE()
endfunction

function! targets#target#string() dict
    if self.error != ''
        return '[err:' . self.error . ']'
    endif

    let text = ''
    if self.sl == self.el
        let text = getline(self.sl)[self.sc-1:self.ec-1]
    else
        let text = getline(self.sl)[self.sc-1 :] . '...' . getline(self.el)[: self.ec-1]
    endif

    if has_key(self, 'gen')
        let text .= ' ' . self.gen.kind . self.gen.trigger
    endif

    return text . ' ' . '[' . self.sl . ' ' . self.sc . '; ' . self.el . ' ' . self.ec . ']'
endfunction
