" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license
" Updated: 2014-02-24
" Version: 0.0.4

let s:save_cpoptions = &cpoptions
set cpo&vim

" visually select some text for the given delimiters and matchers
" `matchers` is a list of functions that gets executed in order
" it consists of optional position modifiers, followed by a match selector,
" followed by optional selection modifiers
function! targets#omap(delimiters, matchers)
    call s:init(a:delimiters, v:count1)
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
    call s:init(a:delimiters, a:count)
    call s:findMatch(a:matchers)
    call s:handleMatch()
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
function! s:init(delimiters, count)
    let s:count = a:count
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

" clean up script variables after match
function! s:cleanUp()
    unlet s:count
    unlet s:opening
    unlet s:closing
    unlet s:sl s:sc s:el s:ec
    unlet s:oldpos
    unlet s:failed
endfunction

function! s:clearCommandLine()
    if v:operator != 'c'
        call feedkeys(":\<C-C>", 'n')
    endif
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
    " insert single character and visually select it
    silent! execute "normal! ix\<Esc>v"
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
        call feedkeys(":call targets#undo(" . undoseq . ")\<CR>", 'n')
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
    if getline('.')[col('.')-1] == s:opening
        let oldpos = getpos('.')
        let closing = 1
        let line = 1
        while line != 0
            let [line, _] = searchpos(s:opening, 'b', line('.'))
            let closing = !closing
        endwhile
        call setpos('.', oldpos)
        if closing " cursor is on closing delimiter
            silent! normal! h
        endif
        unlet oldpos closing line
    endif
endfunction

" find `count` next delimiter (multi line)
" in   │     ...
" line │  '  '  '  '
" out  │        1  2
function! s:next()
    for _ in range(s:count)
        call searchpos(s:opening, '')
    endfor
    let s:count = 1
endfunction

" find `count` last delimiter, move in front of it (multi line)
" in   │     ...
" line │  '  '  '  '
" out  │ 2  1
function! s:last()
    " only the first delimiter can match at current position
    call searchpos(s:closing, 'bc')
    for _ in range(s:count - 1)
        call searchpos(s:closing, 'b')
    endfor
    let s:count = 1
    silent! normal! h
endfunction

" find `count` next opening delimiter (multi line)
" in   │ ....
" line │ ( ) ( ) ( ( ) ) ( )
" out  │     1   2 3     4
function! s:nextp()
    for _ in range(s:count)
        call searchpos(s:opening, '')
    endfor
    let s:count = 1
endfunction

" find `count` last closing delimiter (multi line)
" in   │               ....
" line │ ( ) ( ) ( ( ) ) ( )
" out  │   4   3     2 1
function! s:lastp()
    for _ in range(s:count)
        call searchpos(s:closing, 'b')
    endfor
    let s:count = 1
endfunction

" if there's no opening delimiter to the left, search to the right
" if there's no closing delimiter to the right, search to the left
" uses count for next or last
" in   │ ..     │  .   │     ..
" line │ a '  ' │ ' '  │ '  ' b
" out  │   1  2 │  .   │ 2  1
function! s:seek()
    let [line, _] = searchpos(s:opening, 'bcn', line('.'))
    if line == 0 " no match to the left
        call s:next()
    endif
    let [line, _] = searchpos(s:closing, 'n', line('.'))
    if line == 0 " no match to the right
        call s:last()
    endif
    unlet line
endfunction

" match selectors
" ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

" select pair of delimiters around cursor (multi line)
" select to the right if cursor is on a delimiter
" cursor  │   ....
" line    │ ' ' b ' '
" matcher │   └───┘
function! s:select()
    let [s:sl, s:sc] = searchpos(s:opening, 'bc')
    if s:sc == 0 " no match to the left
        return s:setFailed()
    endif
    let [s:el, s:ec] = searchpos(s:closing, '')
    if s:ec == 0 " no match to the right
        return s:setFailed()
    endif
endfunction

" pair matcher (works across multiple lines)
" cursor   │   .....
" line     │ ( ( a ) )
" modifier │ │ └─1─┘ │
"          │ └── 2 ──┘
function! s:selectp()
    " `normal! %` doesn't work with `<>`
    silent! execute 'normal! v'
    for _ in range(s:count)
        silent! execute 'normal! a' . s:opening
        " TODO: fail if selection didn't change
    endfor

    let s:count = 1
    let [_, s:el, s:ec, _] = getpos('.')
    silent! normal! o
    let [_, s:sl, s:sc, _] = getpos('.')
    silent! normal! v
    if s:sc == s:ec
        return s:setFailed()
    endif
endfunction

" selects the current cursor position (useful to test modifiers)
function! s:position()
    let [_, s:sl, s:sc, _] = getpos('.')
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
    let [_, s:sl, s:sc, _] = getpos('.')
    call cursor(s:el, s:ec)
    silent! execute "normal! \<BS>"
    let [_, s:el, s:ec, _] = getpos('.')
endfunction

" drop right delimiter
" in   │   ┌─────┐
" line │ a . b c . d
" out  │   └────┘
function! s:dropr()
    let s:ec -= 1
endfunction

" drop delimters and whitespace left and right
" fall back to drop when only whitespace is inside
" in   │   ┌─────┐   │   ┌──┐
" line │ a . b c . d │ a .  . d
" out  │     └─┘     │    └┘
function! s:shrink()
    call cursor(s:el, s:ec)
    let [s:el, s:ec] = searchpos('\S', 'b', line('.'))
    if s:ec <= s:sc
        " fall back to drop when there's only whitespace in between
        return s:drop()
    endif
    call cursor(s:sl, s:sc)
    let [s:sl, s:sc] = searchpos('\S', '', line('.'))
endfunction

" expand selection by some whitespace
" prefer to expand to the right, don't expand when there is none
" in   │   ┌───┐   │   ┌───┐  │  ┌───┐  │ ┌───┐
" line │ a . b . c │ a . b .c │ a. c .c │ . a .c
" out  │   └────┘  │  └────┘  │  └───┘  │└────┘
function! s:expand()
    call cursor(s:el, s:ec)
    let [line, column] = searchpos('\S\|$', '', line('.'))
    if line > 0 && column-1 > s:ec
        " non whitespace or EOL after trailing whitespace found
        let s:el = line
        let s:ec = column-1
        unlet line column
        return
    endif
    call cursor(s:sl, s:sc)
    let [line, column] = searchpos('\S', 'b', line('.'))
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

" doubles the count (used for `iN'`)
function! s:double()
    let s:count = s:count * 2
endfunction

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
