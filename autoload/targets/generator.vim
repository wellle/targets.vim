function! targets#generator#new(genFunc, modFuncs, source, args, oldpos, which)
    return {
                \ 'genFunc':  a:genFunc,
                \ 'modFuncs': a:modFuncs,
                \ 'source':   a:source,
                \ 'args':     a:args,
                \
                \ 'oldpos':   a:oldpos,
                \ 'which':    a:which,
                \ 'state':    {},
                \
                \ 'next':   function('targets#generator#next'),
                \ 'nextN':  function('targets#generator#nextN'),
                \ 'target': function('targets#generator#target')
                \ }
endfunction

function! targets#generator#next(first) dict
    call setpos('.', self.oldpos)
    " TODO: don't pass self (gen), but args and state separately?
    " no need to access anything else in there
    " TODO: how about having this function return [a, b, c, d] instead of a
    " target? maybe return string as error?
    let target = call(self.genFunc, [self, a:first])
    if mode() == 'v'
        normal! v
        " TODO: make argument optional, we only need it in init()
        let target = targets#target#fromVisualSelection('')
    elseif type(target) == type(0) && target == 0
        " empty return, no target
        return targets#target#withError('no target')
    elseif type(target) != type({})
        echom "targets.vim source '" . self.source . "' genFunc for " . self.which . " returned unexpected " . string(target)
        return targets#target#withError('bad target')
    endif

    let target.gen = self
    let self.currentTarget = target
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

