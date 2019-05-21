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
    let opts = {'first': a:first}

    let target = call(self.genFunc, [self.args, opts, self.state])

    if type(target) == type(0) && target == 0
        " no/empty return
        if mode() != 'v'
            " not in visual mode, no target
            let target = targets#target#withError('no target')
        else
            " in visual mode, take selection as target
            normal! v
            let target = targets#target#fromVisualSelection()
        endif

    elseif type(target) == type('')
        " returned string, taken as error message
        let target = targets#target#withError(target)

    elseif type(target) == type([]) && len(target) == 4
        " returned list of four, taken as [sl, sc, el, ec]
        " NOTE: still fails if a list of four non ints gets returned, ignored
        " for now
        let target = targets#target#fromValues(target[0], target[1], target[2], target[3])

    elseif type(target) != type({})
        echom "targets.vim source '" . self.source . "' genFunc for " . self.which . " returned unexpected " . string(target)
        let target = targets#target#withError('bad target')
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
        let [target, ok] = self.next(i == a:first)
        if !ok
            return target
        endif
    endfor

    return target
endfunction

