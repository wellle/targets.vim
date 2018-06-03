function! targets#sources#arguments#new(opening, closing, separator)
    let args = {
                \ 'opening':   a:opening,
                \ 'closing':   a:closing,
                \ 'separator': a:separator,
                \ 'openingS':  a:opening . '\|' . a:separator,
                \ 'closingS':  a:closing . '\|' . a:separator,
                \ 'all':       a:opening . '\|' . a:separator . '\|' . a:closing,
                \ 'outer':     a:opening . '\|' . a:closing,
                \ }
    let genFuncs = {
                \ 'c': function('targets#sources#arguments#current'),
                \ 'n': function('targets#sources#arguments#next'),
                \ 'l': function('targets#sources#arguments#last'),
                \ }
    let modFuncs = {
                \ 'i': function('targets#modify#drop'),
                \ 'a': function('targets#modify#dropa'),
                \ 'I': function('targets#modify#shrink'),
                \ 'A': function('targets#modify#expand'),
                \ }
    return targets#factory#new('a', args, genFuncs, modFuncs)
endfunction

function! targets#sources#arguments#current(gen, first)
    if a:first
        let target = s:select(a:gen, '^')
    else
        if s:findArgBoundary('cW', 'cW', a:gen.args.opening, a:gen.args.closing, a:gen.args.outer, "")[2] > 0
            return targets#target#withError('AC 1')
        endif
        silent! execute "normal! 1 "
        let target = s:select(a:gen, '<')
    endif

    call target.cursorE() " keep going from right end
    return target
endfunction

function! targets#sources#arguments#next(gen, first)
    " search for opening or separator, try to select argument from there
    " if that fails, keep searching for opening until an argument can be
    " selected
    let pattern = a:gen.args.openingS
    while 1
        if targets#util#search(pattern, 'W') > 0
            return targets#target#withError('no target')
        endif

        let oldpos = getpos('.')
        let target = s:select(a:gen, '>')
        call setpos('.', oldpos)

        if target.state().isValid()
            return target
        endif

        let pattern = a:gen.args.opening
    endwhile
endfunction

function! targets#sources#arguments#last(gen, first)
    " search for closing or separator, try to select argument from there
    " if that fails, keep searching for closing until an argument can be
    " selected
    let pattern = a:gen.args.closingS
    while 1
        if targets#util#search(pattern, 'bW') > 0
            return targets#target#withError('no target')
        endif

        let oldpos = getpos('.')
        let target = s:select(a:gen, '<')
        call setpos('.', oldpos)

        if target.state().isValid()
            return target
        endif

        let pattern = a:gen.args.closing
    endwhile
endfunction

" select an argument around the cursor
" parameter direction decides where to select when invoked on a separator:
"   '>' select to the right (default)
"   '<' select to the left (used when selecting or skipping to the left)
"   '^' select up (surrounding argument, used for growing)
function! s:select(gen, direction)
    let oldpos = getpos('.')

    let [opening, closing] = [a:gen.args.opening, a:gen.args.closing]
    if a:direction ==# '^'
        if s:getchar() =~# closing
            let [sl, sc, el, ec, err] = s:findArg(a:gen.args, a:direction, 'cW', 'bW', 'bW', opening, closing)
        else
            let [sl, sc, el, ec, err] = s:findArg(a:gen.args, a:direction, 'W', 'bcW', 'bW', opening, closing)
        endif
        let message = 'argument select 1'
    elseif a:direction ==# '>'
        let [sl, sc, el, ec, err] = s:findArg(a:gen.args, a:direction, 'W', 'bW', 'bW', opening, closing)
        let message = 'argument select 2'
    elseif a:direction ==# '<' " like '>', but backwards
        let [el, ec, sl, sc, err] = s:findArg(a:gen.args, a:direction, 'bW', 'W', 'W', closing, opening)
        let message = 'argument select 3'
    else
        return targets#target#withError('argument select')
    endif

    if err > 0
        call setpos('.', oldpos)
        return targets#target#withError(message)
    endif

    return targets#target#fromValues(sl, sc, el, ec)
endfunction

" find an argument around the cursor given a direction (see s:select)
" uses flags1 to search for end to the right; flags1 and flags2 to search for
" start to the left
function! s:findArg(args, direction, flags1, flags2, flags3, opening, closing)
    let oldpos = getpos('.')
    let char = s:getchar()
    let separator = a:args.separator

    if char =~# a:closing && a:direction !=# '^' " started on closing, but not up
        let [el, ec] = oldpos[1:2] " use old position as end
    else " find end to the right
        let [el, ec, err] = s:findArgBoundary(a:flags1, a:flags1, a:opening, a:closing, a:args.all, a:args.separator)
        if err > 0 " no closing found
            return [0, 0, 0, 0, targets#util#fail('findArg 1', a:)]
        endif

        let separator = a:args.separator
        if char =~# a:opening || char =~# separator " started on opening or separator
            let [sl, sc] = oldpos[1:2] " use old position as start
            return [sl, sc, el, ec, 0]
        endif

        call setpos('.', oldpos) " return to old position
    endif

    " find start to the left
    let [sl, sc, err] = s:findArgBoundary(a:flags2, a:flags3, a:closing, a:opening, a:args.all, a:args.separator)
    if err > 0 " no opening found
        return [0, 0, 0, 0, targets#util#fail('findArg 2')]
    endif

    return [sl, sc, el, ec, 0]
endfunction

" find arg boundary by search for `finish` or `separator` while skipping
" matching `skip`s
" example: find ',' or ')' while skipping a pair when finding '('
" args (flags1, flags2, skip, finish, all=all,
" separator=separator, cnt=2)
" return (line, column, err)
" separator can be empty and means it should never match
function! s:findArgBoundary(flags1, flags2, skip, finish, all, separator)

    let [tl, rl, rc] = [0, 0, 0]
    let [rl, rc] = searchpos(a:all, a:flags1)
    while 1
        if rl == 0
            return [0, 0, targets#util#fail('findArgBoundary 1', a:)]
        endif

        let char = s:getchar()
        if a:separator != "" && char =~# a:separator
            if tl == 0
                let [tl, tc] = [rl, rc]
            endif
        elseif char =~# a:finish
            if tl > 0
                return [tl, tc, 0]
            endif
            break
        elseif char =~# a:skip
            silent! keepjumps normal! %
        else
            return [0, 0, targets#util#fail('findArgBoundary 2')]
        endif
        let [rl, rc] = searchpos(a:all, a:flags2)
    endwhile

    return [rl, rc, 0]
endfunction

" returns the character under the cursor
function! s:getchar()
    return getline('.')[col('.')-1]
endfunction

