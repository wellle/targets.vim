" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license
" Updated: 2014-02-03
" Version: 0.0.1

let s:save_cpoptions = &cpoptions
set cpo&vim

" visually select some text for the given delimiters and matchers
" `matchers` is a list of functions that gets executed in order
" it consists of optional position modifiers, followed by a match selector,
" followed by optional selection modifiers
function! targets#match(opening, closing, matchers)
    call targets#init(a:opening, a:closing)
    call targets#findMatch(a:matchers)
    call targets#handleMatch()
    call targets#cleanUp()
endfunction

" initialize script local variables for the current matching
function! targets#init(opening, closing)
    let s:count = v:count1
    let s:opening = escape(a:opening, '".~\')
    let s:closing = escape(a:closing, '".~\')
    let [s:sl, s:sc, s:el, s:ec] = [0, 0, 0, 0]
    let s:oldpos = getpos('.')
    let s:failed = 0
endfunction

" clean up script variables after match
function! targets#cleanUp()
    unlet s:count
    unlet s:opening
    unlet s:closing
    unlet s:sl s:sc s:el s:ec
    unlet s:oldpos
    unlet s:failed
endfunction

" try to find match and return 1 in case of success
function! targets#findMatch(matchers)
    for matcher in split(a:matchers)
        let Matcher = function('targets#' . matcher)
        call Matcher()
        if s:failed
            break
        endif
    endfor
    unlet! Matcher
endfunction

function! targets#handleMatch()
    if s:failed || s:sl == 0 || s:el == 0
        call targets#abortMatch()
    elseif s:sl < s:el
        call targets#selectMatch()
    elseif s:sl > s:el
        call targets#abortMatch()
    elseif s:sc > s:ec
        call targets#abortMatch()
    else
        call targets#selectMatch()
    endif
endfunction

function! targets#selectMatch()
    call cursor(s:sl, s:sc)
    normal! v
    call cursor(s:el, s:ec)
endfunction

function! targets#abortMatch()
    call setpos('.', s:oldpos)
    " get into normal mode and beep
    execute "normal! \<C-\>\<C-N>\<Esc>"
    return
endfunction

" mark current matching run as failed
function! targets#setFailed()
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
function! targets#quote()
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

" find `count` next delimiter (single line)
" in   │     ...
" line │  '  '  '  '
" out  │        1  2
function! targets#next()
    for _ in range(s:count)
        call searchpos(s:opening, '', line('.'))
    endfor
    let s:count = 1
endfunction

" find `count` last delimiter, move in front of it (single line)
" in   │     ...
" line │  '  '  '  '
" out  │ 2  1
function! targets#last()
    " only the first delimiter can match at current position
    call searchpos(s:closing, 'bc', line('.'))
    for _ in range(s:count - 1)
        call searchpos(s:closing, 'b', line('.'))
    endfor
    let s:count = 1
    silent! normal! h
endfunction

" find `count` next opening delimiter (multi line)
" in   │ ....
" line │ ( ) ( ) ( ( ) ) ( )
" out  │     1   2 3     4
function! targets#nextp()
    for _ in range(s:count)
        call searchpos(s:opening, '')
    endfor
    let s:count = 1
endfunction

" find `count` last closing delimiter (multi line)
" in   │               ....
" line │ ( ) ( ) ( ( ) ) ( )
" out  │   4   3     2 1
function! targets#lastp()
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
function! targets#seek()
    let [line, _] = searchpos(s:opening, 'bcn', line('.'))
    if line == 0 " no match to the left
        call targets#next()
    endif
    let [line, _] = searchpos(s:closing, 'n', line('.'))
    if line == 0 " no match to the right
        call targets#last()
    endif
    unlet line
endfunction

" match selectors
" ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

" select pair of delimiters around cursor
" select to the right if cursor is on a delimiter
" cursor  │   ....
" line    │ ' ' b ' '
" matcher │   └───┘
function! targets#select()
    let [s:sl, s:sc] = searchpos(s:opening, 'bc', line('.'))
    if s:sc == 0 " no match to the left
        return targets#setFailed()
    endif
    let [s:el, s:ec] = searchpos(s:closing, '', line('.'))
    if s:ec == 0 " no match to the right
        return targets#setFailed()
    endif
endfunction

" pair matcher (works across multiple lines)
" cursor   │   .....
" line     │ ( ( a ) )
" modifier │ │ └─1─┘ │
"          │ └── 2 ──┘
function! targets#selectp()
    " `normal! %` doesn't work with `<>`
    silent! execute 'normal! v'
    for _ in range(s:count)
        silent! execute 'normal! a' . s:opening
        " TODO: fail if selection didn't change
    endfor

    let s:count = 1
    let [_, s:el, s:ec, _] = getpos('.')
    normal! o
    let [_, s:sl, s:sc, _] = getpos('.')
    normal! v
    if s:sc == s:ec
        return targets#setFailed()
    endif
endfunction

" selects the current cursor position (useful to test modifiers)
function! targets#position()
    let [_, s:sl, s:sc, _] = getpos('.')
    let [s:el, s:ec] = [s:sl, s:sc]
endfunction

" selection modifiers
" ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

" drop delimiters left and right
" in   │   ┌─────┐
" line │ a .  b  . c
" out  │    └───┘
function! targets#drop()
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
function! targets#dropr()
    let s:ec -= 1
endfunction

" drop delimters and whitespace left and right
" fall back to drop when only whitespace is inside
" in   │   ┌─────┐   │   ┌──┐
" line │ a . b c . d │ a .  . d
" out  │     └─┘     │    └┘
function! targets#shrink()
    call cursor(s:el, s:ec)
    let [s:el, s:ec] = searchpos('\S', 'b', line('.'))
    if s:ec <= s:sc
        " fall back to drop when there's only whitespace in between
        call targets#drop()
        return
    endif
    call cursor(s:sl, s:sc)
    let [s:sl, s:sc] = searchpos('\S', '', line('.'))
endfunction

" expand selection by some whitespace
" prefer to expand to the right, don't expand when there is none
" in   │   ┌───┐   │   ┌───┐  │  ┌───┐  │ ┌───┐
" line │ a . b . c │ a . b .c │ a. c .c │ . a .c
" out  │   └────┘  │  └────┘  │  └───┘  │└────┘
function! targets#expand()
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
function! targets#double()
    let s:count = s:count * 2
endfunction

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
