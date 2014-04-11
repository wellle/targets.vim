" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license
" Updated: 2014-04-11
" Version: 0.1.4

let s:save_cpoptions = &cpoptions
set cpo&vim

" visually select some text for the given delimiters and matchers
" `matchers` is a list of functions that gets executed in order
" it consists of optional position modifiers, followed by a match selector,
" followed by optional selection modifiers
function! targets#omap(delimiters, matchers)
    call s:init(a:delimiters, a:matchers, v:count1)
    call s:findMatch(a:matchers)
    call s:handleMatch()
    call s:clearCommandLine()
    call s:cleanUp()
endfunction

" like targets#omap, but don't clear the command line
function! targets#xmap(delimiters, matchers)
    call targets#xmapCount(a:delimiters, a:matchers, v:count1)
endfunction

" like targets#xmap, but inject count, triggered from targets#xmapExpr
function! targets#xmapCount(delimiters, matchers, count)
    call s:init(a:delimiters, a:matchers, a:count)
    call s:findMatch(a:matchers)
    call s:handleMatch()
    call s:saveState()
    call s:cleanUp()
endfunction

" called on `vA` and `vI` to start visual mappings like `vAn,`
" we use it like this to still allow to append after visually selected blocks
function! targets#uppercaseXmap(trigger)
    " only supported for character wise visual mode
    if mode() !=# 'v'
        return a:trigger
    endif

    " read characters like `n` and `,` for `vAn,`
    let chars = nr2char(getchar())
    if chars =~? '^[nl]'
        let chars .= nr2char(getchar())
    endif

    " get associated arguments for targets#xmapCount
    let arguments = get(g:targets#mapArgs, a:trigger . chars, '')
    if arguments == ''
        return '\<Esc>'
    endif

    " exit visual mode and call targets#xmapCount
    return "\<Esc>:\<C-U>call targets#xmapCount(" . arguments . ", " . v:count1 . ")\<CR>"
endfunction

" initialize script local variables for the current matching
function! s:init(delimiters, matchers, count)
    let [s:delimiters, s:matchers, s:count] = [a:delimiters, a:matchers,  a:count]
    let [s:sl, s:sc, s:el, s:ec] = [0, 0, 0, 0]
    let s:oldpos = getpos('.')
    let s:failed = 0

    let s:opening = escape(a:delimiters[0], '".~\')
    if len(a:delimiters) == 2
        let s:closing = escape(a:delimiters[1], '".~\')
    else
        let s:closing = s:opening
    endif
endfunction

" remember last selection, delimiters and matchers
function s:saveState()
    let [s:lsl, s:lsc, s:lel, s:lec] = [s:sl, s:sc, s:el, s:ec]
    let [s:ldelimiters, s:lmatchers] = [s:delimiters, s:matchers]
endfunction

" clean up script variables after match
function! s:cleanUp()
    unlet s:delimiters s:matchers s:count
    unlet s:sl s:sc s:el s:ec
    unlet s:oldpos
    unlet s:failed
    unlet s:opening s:closing
endfunction

" clear the commandline to hide targets function calls
function! s:clearCommandLine()
    echo
endfunction

" try to find match and return 1 in case of success
function! s:findMatch(matchers)
    for matcher in split(a:matchers)
        let Matcher = function('s:' . matcher)
        call Matcher()
        if s:failed
            break
        endif
    endfor
    unlet! Matcher
endfunction

" handle the match by either selecting or aborting it
function! s:handleMatch()
    if s:failed || s:sl == 0 || s:el == 0
        call s:abortMatch()
    elseif s:sl < s:el
        call s:selectMatch()
    elseif s:sl > s:el
        call s:abortMatch()
    elseif s:sc == s:ec + 1
        call s:handleEmptyMatch()
    elseif s:sc > s:ec
        call s:abortMatch()
    else
        call s:selectMatch()
    endif
endfunction

" select a proper match
function! s:selectMatch()
    " add old position to jump list
    call setpos('.', s:oldpos)
    normal! m'

    call cursor(s:sl, s:sc)
    silent! normal! v
    call cursor(s:el, s:ec)
endfunction

" empty matches can't visually be selected
" most operators would like to move to the end delimiter
" for change or delete, insert temporary character that will be operated on
function! s:handleEmptyMatch()
    if v:operator !~# "^[cd]$"
        return s:abortMatch()
    endif

    " move cursor to delimiter after zero width match
    call cursor(s:sl, s:sc)
    " insert single space and visually select it
    silent! execute "normal! i \<Esc>v"
endfunction

" abort when no match was found
function! s:abortMatch()
    call setpos('.', s:oldpos)
    " get into normal mode and beep
    call feedkeys("\<C-\>\<C-N>\<Esc>", 'n')
    " undo partial command
    call s:triggerUndo()
endfunction

" feed keys to call undo after aborted operation and clear the command line
function! s:triggerUndo()
    if exists("*undotree")
        let undoseq = undotree().seq_cur
        call feedkeys(":call targets#undo(" . undoseq . ")\<CR>:echo\<CR>", 'n')
    endif
endfunction

" undo last operation if it created a new undo position
function! targets#undo(lastseq)
    if undotree().seq_cur > a:lastseq
        silent! execute "normal! u"
    endif
endfunction

" mark current matching run as failed
function! s:setFailed()
    let s:failed = 1
endfunction

" position modifiers
" ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

" move the cursor inside of a proper quote when positioned on a delimiter
" (move one character to the left when over an odd number of quotation mark)
" the number of delimiters to the left of the cursor is counted to decide
" if this is an opening or closing quote delimiter
" in   │ . │  . │ . │  .
" line │ ' │  ' │ ' │  '
" out  │ . │ .  │ . │ .
function! s:quote()
    if getline('.')[col('.')-1] != s:delimiters[0]
        return
    endif

    let oldpos = getpos('.')
    let closing = 1
    let line = 1
    while line != 0
        let line = searchpos(s:opening, 'bW', line('.'))[0]
        let closing = !closing
    endwhile
    call setpos('.', oldpos)
    if closing " cursor is on closing delimiter
        silent! normal! h
    endif
    unlet oldpos closing line
endfunction

" find `count` next delimiter (multi line)
" in   │     ...
" line │  '  '  '  '
" out  │        1  2
function! s:next()
    for _ in range(s:count)
        call searchpos(s:opening, 'W')
    endfor
    let s:count = 1
endfunction

" find `count` last delimiter, move in front of it (multi line)
" in   │     ...
" line │  '  '  '  '
" out  │ 2  1
function! s:last()
    " only the first delimiter can match at current position
    call searchpos(s:closing, 'bcW')
    for _ in range(s:count - 1)
        call searchpos(s:closing, 'bW')
    endfor
    let s:count = 1
    silent! normal! h
endfunction

" find `count` next opening delimiter (multi line)
" in   │ ....
" line │ ( ) ( ) ( ( ) ) ( )
" out  │     1   2 3     4
function! s:nextp(...)
    if a:0 == 1
        let opening = a:1
    else
        let opening = s:opening
    endif

    " find `count` next opening
    for _ in range(s:count)
        let line = searchpos(opening, 'W')[0]
        if line == 0 " not enough found
            return s:setFailed()
        endif
    endfor
    let s:count = 1
endfunction

" find `count` last closing delimiter (multi line)
" in   │               ....
" line │ ( ) ( ) ( ( ) ) ( )
" out  │   4   3     2 1
function! s:lastp(...)
    if a:0 == 1
        let closing = a:1
    else
        let closing = s:closing
    endif

    " find `count` last closing
    for _ in range(s:count)
        let line = searchpos(closing, 'bW')[0]
        if line == 0 " not enough found
            return s:setFailed()
        endif
    endfor
    let s:count = 1
endfunction

" find `count` next opening tag delimiter (multi line)
" in   │ .........
" line │ <a> </a> <b> </b> <c> <d> </d> </c> <e> </e>
" out  │          1        2   3             4
function! s:nextt()
    return s:nextp('<\a')
endfunction

" find `count` last closing tag delimiter (multi line)
" in   │                                    .........
" line │ <a> </a> <b> </b> <c> <d> </d> </c> <e> </e>
" out  │     4        3            2    1
function! s:lastt()
    return s:lastp('</\a')
endfunction

" match selectors
" ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

" select pair of delimiters around cursor (multi line, no seeking)
" select to the right if cursor is on a delimiter
" cursor  │   ....
" line    │ ' ' b ' '
" matcher │   └───┘
function! s:select()
    let [s:sl, s:sc] = searchpos(s:opening, 'bcW')
    if s:sc == 0 " no match to the left
        return s:setFailed()
    endif
    let [s:el, s:ec] = searchpos(s:closing, 'W')
    if s:ec == 0 " no match to the right
        return s:setFailed()
    endif
endfunction

" select pair of delimiters around cursor (multi line, no seeking)
function! s:seekselect()
    let [rl, rc] = searchpos(s:opening, 'W', line('.'))
    if rl > 0 " delim r found after cursor in line
        let [s:sl, s:sc] = searchpos(s:opening, 'bW', line('.'))
        if s:sl > 0 " delim found before r in line
            let [s:el, s:ec] = [rl, rc]
            return
        endif
        " no delim before cursor in line
        let [s:el, s:ec] = searchpos(s:opening, 'W', line('.'))
        if s:el > 0 " delim found after r in line
            let [s:sl, s:sc] = [rl, rc]
            return
        endif
        " no delim found after r in line
        let [s:sl, s:sc] = searchpos(s:opening, 'bW')
        if s:sl > 0 " delim found before r
            let [s:el, s:ec] = [rl, rc]
            return
        endif
        " no delim found before r
        let [s:el, s:ec] = searchpos(s:opening, 'W')
        if s:el > 0 " delim found after r
            let [s:sl, s:sc] = [rl, rc]
            return
        endif
        " no delim found after r
        return s:setFailed()
    endif

    " no delim found after cursor in line
    let [ll, lc] = searchpos(s:opening, 'bcW', line('.'))
    if ll > 0 " delim l found before cursor in line
        let [s:sl, s:sc] = searchpos(s:opening, 'bW', line('.'))
        if s:sl > 0 " delim found before l in line
            let [s:el, s:ec] = [ll, lc]
            return
        endif
        " no delim found before l in line
        let [s:el, s:ec] = searchpos(s:opening, 'W')
        if s:el > 0 " delim found after l
            let [s:sl, s:sc] = [ll, lc]
            return
        endif
        " no delim found after l
        let [s:sl, s:sc] = searchpos(s:opening, 'bW')
        if s:sl > 0 " delim found before l
            let [s:el, s:ec] = [ll, lc]
            return
        endif
        " no delim found before l
        return s:setFailed()
    endif

    " no delim found before cursor in line
    let [rl, rc] = searchpos(s:opening, 'W')
    if rl > 0 " delim r found after cursor
        let [s:sl, s:sc] = searchpos(s:opening, 'bW')
        if s:sl > 0 " delim found before r
            let [s:el, s:ec] = [rl, rc]
            return
        endif
        " no delim found before r
        let [s:el, s:ec] = searchpos(s:opening, 'W')
        if s:el > 0 " delim found after r
            let [s:sl, s:sc] = [rl, rc]
            return
        endif
        " no delim found after r
        return s:setFailed()
    endif

    " no delim found after cursor
    let [s:el, s:ec] = searchpos(s:opening, 'bW')
    let [s:sl, s:sc] = searchpos(s:opening, 'bW')
    if s:sl > 0 && s:el > 0 " match found before cursor
        return
    endif
    return s:setFailed()
endfunction

" pair matcher (works across multiple lines, no seeking)
" cursor   │   .....
" line     │ ( ( a ) )
" modifier │ │ └─1─┘ │
"          │ └── 2 ──┘
function! s:selectp()
    " try to select pair
    silent! execute 'normal! va' . s:opening
    let [s:el, s:ec] = getpos('.')[1:2]
    silent! normal! o
    let [s:sl, s:sc] = getpos('.')[1:2]
    silent! normal! v

    if s:sc == s:ec && s:sl == s:el
        return s:setFailed() " no match found
    endif
endfunction

" pair matcher (works across multiple lines, supports seeking)
function! s:seekselectp(...)
    if a:0 == 3
        let [ opening, closing, trigger ] = [ a:1, a:2, a:3 ]
    else
        let [ opening, closing, trigger ] = [ s:opening, s:closing, s:closing ]
    endif

    " try to select around cursor
    silent! execute 'normal! v' . s:count . 'a' . trigger
    let [s:el, s:ec] = getpos('.')[1:2]
    silent! normal! o
    let [s:sl, s:sc] = getpos('.')[1:2]
    silent! normal! v

    if s:sc != s:ec || s:sl != s:el
        " found target around cursor
        let s:count = 1
        return
    endif

    if s:count > 1
        " don't seek when count was given
        return s:setFailed()
    endif
    let s:count = 1

    let [s:sl, s:sc] = searchpos(opening, 'W', line('.'))
    if s:sc > 0 " found opening to the right in line
        return s:selectp()
    endif

    let [s:sl, s:sc] = searchpos(closing, 'Wb', line('.'))
    if s:sc > 0 " found closing to the left in line
        return s:selectp()
    endif

    let [s:sl, s:sc] = searchpos(opening, 'W')
    if s:sc > 0 " found opening to the right
        return s:selectp()
    endif

    let [s:sl, s:sc] = searchpos(closing, 'Wb')
    if s:sc > 0 " found closing to the left
        return s:selectp()
    endif

    return s:setFailed() " no match found
endfunction

" tag pair matcher (works across multiple lines, supports seeking)
function! s:seekselectt()
    return s:seekselectp('<\a', '</\a', 't')
endfunction

" selects the current cursor position (useful to test modifiers)
function! s:position()
    let [s:sl, s:sc] = getpos('.')[1:2]
    let [s:el, s:ec] = [s:sl, s:sc]
endfunction

" selection modifiers
" ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

" drop delimiters left and right
" in   │   ┌─────┐
" line │ a .  b  . c
" out  │    └───┘
function! s:drop()
    call cursor(s:sl, s:sc)
    silent! execute "normal! 1 "
    let [s:sl, s:sc] = getpos('.')[1:2]
    call cursor(s:el, s:ec)
    silent! execute "normal! \<BS>"
    let [s:el, s:ec] = getpos('.')[1:2]
endfunction

" drop right delimiter
" in   │   ┌─────┐
" line │ a . b c . d
" out  │   └────┘
function! s:dropr()
    let s:ec -= 1
endfunction

" drop tag delimiters left and right
" in   │   ┌──────────┐
" line │ a <b>  c  </b> c
" out  │      └───┘
function! s:dropt()
    call cursor(s:sl, s:sc)
    call searchpos('>', 'W')
    silent! execute "normal! 1 "
    let [s:sl, s:sc] = getpos('.')[1:2]
    call cursor(s:el, s:ec)
    call searchpos('<', 'bW')
    silent! execute "normal! \<BS>"
    let [s:el, s:ec] = getpos('.')[1:2]
endfunction

" drop delimters and whitespace left and right
" fall back to drop when only whitespace is inside
" in   │   ┌─────┐   │   ┌──┐
" line │ a . b c . d │ a .  . d
" out  │     └─┘     │    └┘
function! s:shrink()
    call cursor(s:el, s:ec)
    let [s:el, s:ec] = searchpos('\S', 'bW', line('.'))
    if s:ec <= s:sc
        " fall back to drop when there's only whitespace in between
        return s:drop()
    endif
    call cursor(s:sl, s:sc)
    let [s:sl, s:sc] = searchpos('\S', 'W', line('.'))
endfunction

" expand selection by some whitespace
" prefer to expand to the right, don't expand when there is none
" in   │   ┌───┐   │   ┌───┐  │  ┌───┐  │ ┌───┐
" line │ a . b . c │ a . b .c │ a. c .c │ . a .c
" out  │   └────┘  │  └────┘  │  └───┘  │└────┘
function! s:expand()
    call cursor(s:el, s:ec)
    let [line, column] = searchpos('\S\|$', 'W', line('.'))
    if line > 0 && column-1 > s:ec
        " non whitespace or EOL after trailing whitespace found
        let s:el = line
        let s:ec = column-1
        unlet line column
        return
    endif
    call cursor(s:sl, s:sc)
    let [line, column] = searchpos('\S', 'bW', line('.'))
    if line > 0
        " non whitespace before leading whitespace found
        let s:sl = line
        let s:sc = column+1
        unlet line column
        return
    endif
    unlet line column
    " include all leading whitespace from BOL
    let s:sc = 1
endfunction

" grows selection on repeated invocations by increasing s:count
function! s:grow()
    if !exists('s:ldelimiters') " no previous invocation
        return
    endif
    if [s:ldelimiters, s:lmatchers] != [s:delimiters, s:matchers] " different invocation
        return
    endif
    if getpos("'<")[1:2] != [s:lsl, s:lsc] " selection start changed
        return
    endif
    if getpos("'>")[1:2] != [s:lel, s:lec] " selection end changed
        return
    endif

    " increase s:count to grow selection
    let s:count = s:count + 1
endfunction

" doubles the count (used for `iN'`)
function! s:double()
    let s:count = s:count * 2
endfunction

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
