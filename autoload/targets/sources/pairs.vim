function! targets#sources#pairs#new(opening, closing)
    let args = {
                \ 'opening': a:opening,
                \ 'closing': a:closing,
                \ 'trigger': a:closing,
                \ }
    let genFuncs = {
                \ 'C': function('targets#sources#pairs#C'),
                \ 'N': function('targets#sources#pairs#N'),
                \ 'L': function('targets#sources#pairs#L'),
                \ }
    let modFuncs = {
                \ 'i': function('targets#modify#drop'),
                \ 'a': function('targets#modify#keep'),
                \ 'I': function('targets#modify#shrink'),
                \ 'A': function('targets#modify#expand'),
                \ }
    return targets#factory#new(a:closing, args, genFuncs, modFuncs)
endfunction

function! targets#sources#pairs#C(first) dict
    if a:first
        let cnt = 1
    else
        let cnt = 2
    endif

    let target = s:select(cnt, self.trigger, self)
    call target.cursorE() " keep going from right end
    return target
endfunction

function! targets#sources#pairs#N(first) dict
    if targets#util#search(self.opening, 'W') > 0
        return targets#target#withError('no target')
    endif

    let oldpos = getpos('.')
    let target = s:select(1, self.trigger, self)
    call setpos('.', oldpos)
    return target
endfunction

function! targets#sources#pairs#L(first) dict
    if targets#util#search(self.closing, 'bW') > 0
        return targets#target#withError('no target')
    endif

    let oldpos = getpos('.')
    let target = s:select(1, self.trigger, self)
    call setpos('.', oldpos)
    return target
endfunction

" select a pair around the cursor
" args (count, trigger)
function! s:select(count, trigger, gen)
    " try to select pair
    silent! execute 'keepjumps normal! v' . a:count . 'a' . a:trigger
    let [el, ec] = getpos('.')[1:2]
    silent! normal! o
    let [sl, sc] = getpos('.')[1:2]
    silent! normal! v

    if sc == ec && sl == el
        return targets#target#withError('pairs select')
    endif

    return targets#target#fromValues(sl, sc, el, ec, a:gen)
endfunction

