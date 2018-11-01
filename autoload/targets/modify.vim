" selection modifiers
" ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

" doesn't change given target, added for consistency
function! targets#modify#keep(target, args)
endfunction

" drop delimiters left and right
" remove last line of multiline selection if it consists of whitespace only
" in   │   ┌─────┐
" line │ a .  b  . c
" out  │    └───┘
function! targets#modify#drop(target, args)
    if a:target.state().isInvalid()
        return
    endif

    let [sLinewise, eLinewise] = [0, 0]
    call a:target.cursorS()
    if searchpos('\S', 'nW', line('.'))[0] == 0
        " if only whitespace after cursor
        let sLinewise = 1
    endif
    silent! execute "normal! 1 "
    call a:target.setS()

    call a:target.cursorE()
    if a:target.sl < a:target.el && searchpos('\S', 'bnW', line('.'))[0] == 0
        " if only whitespace in front of cursor
        let eLinewise = 1
        " move to end of line above
        normal! -$
    else
        " one character back
        silent! execute "normal! \<BS>"
    endif
    call a:target.setE()
    let a:target.linewise = sLinewise && eLinewise
endfunction

" drop right delimiter
" in   │   ┌─────┐
" line │ a . b c . d
" out  │   └────┘
function! targets#modify#dropr(target, args)
    call a:target.cursorE()
    silent! execute "normal! \<BS>"
    call a:target.setE()
endfunction

" drop an argument separator (like a comma), prefer the right one, fall back
" to the left (one on first argument)
" in   │ ┌───┐ ┌───┐        ┌───┐        ┌───┐
" line │ ( x ) ( x , a ) (a , x , b) ( a , x )
" out  │  └─┘    └──┘       └──┘        └──┘
function! targets#modify#dropa(target, args)
    let startOpening = a:target.getcharS() !~# a:args.separator
    let endOpening   = a:target.getcharE() !~# a:args.separator

    if startOpening
        if endOpening
            " ( x ) select space on both sides
            return targets#modify#drop(a:target, a:args)
        else
            " ( x , a ) select separator and space after
            call a:target.cursorS()
            call a:target.searchposS('\S', '', a:target.el)
            return targets#modify#expand(a:target, a:args, '>')
        endif
    else
        if !endOpening
            " (a , x , b) select leading separator, no surrounding space
            return targets#modify#dropr(a:target, a:args)
        else
            " ( a , x ) select separator and space before
            call a:target.cursorE()
            call a:target.searchposE('\S', 'b', a:target.sl)
            return targets#modify#expand(a:target, a:args, '<')
        endif
    endif
endfunction

" select inner tag delimiters
" in   │   ┌──────────┐
" line │ a <b>  c  </b> c
" out  │     └─────┘
function! targets#modify#innert(target, args)
    call a:target.cursorS()
    call a:target.searchposS('>', 'W')
    call a:target.cursorE()
    call a:target.searchposE('<', 'bW')
endfunction

" drop delimiters and whitespace left and right
" fall back to drop when only whitespace is inside
" in   │   ┌─────┐   │   ┌──┐
" line │ a . b c . d │ a .  . d
" out  │     └─┘     │    └┘
function! targets#modify#shrink(target, args)
    if a:target.state().isInvalid()
        return
    endif

    call a:target.cursorE()
    call a:target.searchposE('\S', 'b', a:target.sl)
    if a:target.state().isInvalidOrEmpty()
        " fall back to drop when there's only whitespace in between
        return targets#modify#drop(a:target)
    else
        call a:target.cursorS()
        call a:target.searchposS('\S', '', a:target.el)
    endif
endfunction

" expand selection by some whitespace
" in   │   ┌───┐   │   ┌───┐  │  ┌───┐  │ ┌───┐
" line │ a . b . c │ a . b .c │ a. c .c │ . a .c
" out  │   └────┘  │  └────┘  │  └───┘  │└────┘
" args (target, direction=<try right, then left>)
function! targets#modify#expand(target, args, ...)
    if a:0 == 0 || a:1 ==# '>'
        call a:target.cursorE()
        let [line, column] = searchpos('\S\|$', '', line('.'))
        if line > 0 && column-1 > a:target.ec
            " non whitespace or EOL after trailing whitespace found
            " not counting whitespace directly after end
            return a:target.setE(line, column-1)
        endif
    endif

    if a:0 == 0 || a:1 ==# '<'
        call a:target.cursorS()
        let [line, column] = searchpos('\S', 'b', line('.'))
        if line > 0
            " non whitespace before leading whitespace found
            return a:target.setS(line, column+1)
        endif
        " only whitespace in front of start
        " include all leading whitespace from beginning of line
        let a:target.sc = 1
    endif
endfunction

" expand separator selection by one whitespace if there are two
" in   │   ┌───┐   │  ┌───┐   │   ┌───┐  │  ┌───┐  │ ┌───┐
" line │ a . b . c │ a. b . c │ a . b .c │ a. c .c │ . a .c
" out  │   └────┘  │  └───┘   │   └───┘  │  └───┘  │ └───┘
" args (target, direction=<try right, then left>)
function! targets#modify#expands(target, args)
    call a:target.cursorE()
    let [eline, ecolumn] = searchpos('\S\|$', '', line('.'))
    if eline > 0 && ecolumn-1 > a:target.ec

        call a:target.cursorS()
        let [sline, scolumn] = searchpos('\S', 'b', line('.'))
        if sline > 0 && scolumn+1 < a:target.sc

            return a:target.setE(eline, ecolumn-1)
        endif
    endif
endfunction

