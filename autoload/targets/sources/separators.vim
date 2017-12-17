function! targets#sources#separators#new(delimiter)
    let args = {'delimiter': escape(a:delimiter, '.~\$')}
    let genFuncs = {
                \ 'C': function('targets#sources#separators#C'),
                \ 'N': function('targets#sources#separators#N'),
                \ 'L': function('targets#sources#separators#L'),
                \ }
    let modFuncs = {
                \ 'i': function('targets#modify#drop'),
                \ 'a': function('targets#modify#dropr'),
                \ 'I': function('targets#modify#shrink'),
                \ 'A': function('targets#modify#expands'),
                \ }
    return targets#factory#new(a:delimiter, args, genFuncs, modFuncs)
endfunction

function! targets#sources#separators#C(first) dict
    if !a:first
        return targets#target#withError('only one current separator')
    endif

    return targets#util#select(self.delimiter, self.delimiter, '>', self)
endfunction

function! targets#sources#separators#N(first) dict
    if targets#util#search(self.delimiter, 'W') > 0
        return targets#target#withError('no target')
    endif

    let oldpos = getpos('.')
    let target = targets#util#select(self.delimiter, self.delimiter, '>', self)
    call setpos('.', oldpos)
    return target
endfunction

function! targets#sources#separators#L(first) dict
    if a:first
        let flags = 'cbW' " allow separator under cursor on first iteration
    else
        let flags = 'bW'
    endif

    if targets#util#search(self.delimiter, flags) > 0
        return targets#target#withError('no target')
    endif

    let oldpos = getpos('.')
    let target = targets#util#select(self.delimiter, self.delimiter, '<', self)
    call setpos('.', oldpos)
    return target
endfunction


