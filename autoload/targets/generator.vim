" generators get created by factories

function! targets#generator#next(first) dict
    call setpos('.', self.oldpos)
    let self.currentTarget = self.nexti(a:first) " call internal function
    let self.oldpos = getpos('.')
    return self.currentTarget
endfunction

function! targets#generator#target() dict
    return get(self, 'currentTarget', targets#target#withError('no target'))
endfunction

function! targets#generator#nextN(n) dict
    for i in range(1, a:n)
        let target = self.next(i == 1)
        if target.state().isInvalid()
            return target
        endif
    endfor

    return target
endfunction

