" generators get created by factories

function! targets#generator#next(first) dict
    call setpos('.', self.oldpos)
    let self.currentTarget = call(self.genFunc, [self, a:first])
    let self.currentTarget.gen = self
    let self.oldpos = getpos('.')
    return self.currentTarget
endfunction

function! targets#generator#target() dict
    return get(self, 'currentTarget', targets#target#withError('no target'))
endfunction

" if a:first is 1, the first call to next will have first set
function! targets#generator#nextN(n, first) dict
    for i in range(1, a:n)
        let target = self.next(i == a:first)
        if target.state().isInvalid()
            return target
        endif
    endfor

    return target
endfunction

