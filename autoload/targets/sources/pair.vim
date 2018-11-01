function! targets#sources#pair#new(args)
    " args.trigger is used differently from tags source
    return {
                \ 'args': {
                \     'opening': a:args['o'],
                \     'closing': a:args['c'],
                \     'trigger': a:args['c'],
                \ },
                \ 'genFuncs': {
                \     'c': function('targets#sources#pair#current'),
                \     'n': function('targets#sources#pair#next'),
                \     'l': function('targets#sources#pair#last'),
                \ },
                \ 'modFuncs': {
                \     'i': function('targets#modify#drop'),
                \     'a': function('targets#modify#keep'),
                \     'I': function('targets#modify#shrink'),
                \     'A': function('targets#modify#expand'),
                \ }}
endfunction

function! targets#sources#pair#current(args, opts, state)
    if a:opts.first
        let cnt = 1
    else
        let cnt = 2
    endif

    let target = s:select(cnt, a:args.trigger)
    call target.cursorE() " keep going from right end
    return target
endfunction

function! targets#sources#pair#next(args, opts, state)
    if targets#util#search(a:args.opening, 'W') > 0
        return targets#target#withError('no target')
    endif

    let oldpos = getpos('.')
    let target = s:select(1, a:args.trigger)
    call setpos('.', oldpos)
    return target
endfunction

function! targets#sources#pair#last(args, opts, state)
    if targets#util#search(a:args.closing, 'bW') > 0
        return targets#target#withError('no target')
    endif

    let oldpos = getpos('.')
    let target = s:select(1, a:args.trigger)
    call setpos('.', oldpos)
    return target
endfunction

" select a pair around the cursor
" args (count, trigger)
function! s:select(count, trigger)
    " try to select pair
    silent! execute 'keepjumps normal! v' . a:count . 'a' . a:trigger . 'v'
    let target = targets#target#fromVisualSelection()

    if target.sc == target.ec && target.sl == target.el
        return targets#target#withError('pair select')
    endif

    return target
endfunction

