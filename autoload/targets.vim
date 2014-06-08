" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license
" Updated: 2014-06-14
" Version: 0.2.7

let s:save_cpoptions = &cpoptions
set cpo&vim

function! targets#test()
endfunction

" visually select some text for the given delimiters and matchers
" `matchers` is a list of functions that gets executed in order
" it consists of optional position modifiers, followed by a match selector,
" followed by optional selection modifiers
function! targets#omap(delimiters, matchers)
    call s:init('o', a:delimiters, a:matchers, v:count1)
    call s:handleMatch(a:matchers)
    call s:clearCommandLine()
    call s:cleanUp()
endfunction

" like targets#omap, but don't clear the command line
function! targets#xmap(delimiters, matchers)
    call targets#xmapCount(a:delimiters, a:matchers, v:count1)
endfunction

" like targets#xmap, but inject count, triggered from targets#xmapExpr
function! targets#xmapCount(delimiters, matchers, count)
    call s:init('x', a:delimiters, a:matchers, a:count)
    call s:handleMatch(a:matchers)
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
    if arguments ==# ''
        return '\<Esc>'
    endif

    " exit visual mode and call targets#xmapCount
    return "\<Esc>:\<C-U>call targets#xmapCount(" . arguments . ", " . v:count1 . ")\<CR>"
endfunction

" initialize script local variables for the current matching
function! s:init(mapmode, delimiters, matchers, count)
    let [s:mapmode, s:delimiters, s:matchers, s:count] = [a:mapmode, a:delimiters, a:matchers,  a:count]
    let [s:sl, s:sc, s:el, s:ec] = [0, 0, 0, 0]
    let [s:sLinewise, s:eLinewise] = [0, 0]
    let s:oldpos = getpos('.')

    let s:opening = escape(a:delimiters[0], '".~\$')
    if len(a:delimiters) == 2
        let s:closing = escape(a:delimiters[1], '".~\$')
    else
        let s:closing = s:opening
    endif

    let s:selection = &selection " remember 'selection' setting
    let &selection = 'inclusive' " and set it to inclusive
endfunction

" remember last selection, delimiters and matchers
function! s:saveState()
    let [s:lsl, s:lsc, s:lel, s:lec] = [s:sl, s:sc, s:el, s:ec]
    let [s:ldelimiters, s:lmatchers] = [s:delimiters, s:matchers]
endfunction

" clean up script variables after match
function! s:cleanUp()
    let &selection = s:selection " reset 'selection' setting
    unlet s:selection

    unlet s:mapmode s:delimiters s:matchers s:count
    unlet s:sl s:sc s:el s:ec
    unlet s:oldpos
    unlet s:opening s:closing
endfunction

" clear the commandline to hide targets function calls
function! s:clearCommandLine()
    echo
endfunction

" try to find match
function! s:findMatch(matchers)
    for matcher in split(a:matchers)
        let Matcher = function('s:' . matcher)
        if Matcher() > 0
            return s:fail('findMatch')
        endif
    endfor
    unlet! Matcher
endfunction

" handle the match by either selecting or aborting it
function! s:handleMatch(matchers)
    let view = winsaveview()
    let error = s:findMatch(a:matchers)
    call winrestview(view)

    if error || s:sl == 0 || s:el == 0
        return s:abortMatch()
    elseif s:sl < s:el
        call s:selectMatch()
    elseif s:sl > s:el
        return s:abortMatch()
    elseif s:sc == s:ec + 1
        return s:handleEmptyMatch()
    elseif s:sc > s:ec
        return s:abortMatch()
    else
        return s:selectMatch()
    endif
endfunction

" select a proper match
function! s:selectMatch()
    " add old position to jump list
    call setpos('.', s:oldpos)
    normal! m'

    " visually select the match
    call cursor(s:sl, s:sc)

    if s:sLinewise && s:eLinewise
        silent! normal! V
    else
        silent! normal! v
    endif

    call cursor(s:el, s:ec)

    " if selection should be exclusive, expand selection
    if s:selection ==# 'exclusive'
        normal! l
    endif
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

    let eventignore = &eventignore " remember setting
    let &eventignore = 'all' " disable auto commands

    " insert single space and visually select it
    silent! execute "normal! i \<Esc>v"

    let &eventignore = eventignore " restore setting
endfunction

" abort when no match was found
function! s:abortMatch()
    call setpos('.', s:oldpos)
    " get into normal mode and beep
    call feedkeys("\<C-\>\<C-N>\<Esc>", 'n')
    " undo partial command
    call s:triggerUndo()
    " trigger reselect if called from xmap
    call s:triggerReselect()
endfunction

" feed keys to call undo after aborted operation and clear the command line
function! s:triggerUndo()
    if exists("*undotree")
        let undoseq = undotree().seq_cur
        call feedkeys(":call targets#undo(" . undoseq . ")\<CR>:echo\<CR>", 'n')
    endif
endfunction

" feed keys to reselect the last visual selection if called with mapmode x
function! s:triggerReselect()
    if s:mapmode ==# 'x'
        call feedkeys("gv", 'n')
    endif
endfunction

" undo last operation if it created a new undo position
function! targets#undo(lastseq)
    if undotree().seq_cur > a:lastseq
        silent! execute "normal! u"
    endif
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
    if s:getchar() !=# s:delimiters[0]
        return
    endif

    let oldpos = getpos('.')
    let closing = 1
    let line = 1
    while line != 0
        let line = searchpos(s:opening, 'b', line('.'))[0]
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
function! s:nextselect()
    if s:search(s:count, s:opening, 'W') > 0
        return s:fail('nextselect')
    endif
    return s:select('>')
endfunction

" find `count` last delimiter, move in front of it (multi line)
" in   │     ...
" line │  '  '  '  '
" out  │ 2  1
" TODO: was broken when invoked from separator! add test!
" TODO: enable to iterate all pairs in ( ( ) ( ) ) from end
"   by using `>
function! s:lastselect()
    if s:getchar() ==# s:closing
        let [cnt, message] = [s:count - 1, 'lastselect 1']
    else
        let [cnt, message] = [s:count, 'lastselect 2']
    endif

    if s:search(cnt, s:closing, 'bW') > 0
        return s:fail(message)
    endif

    return s:select('<')
endfunction

" find `count` next opening delimiter (multi line)
" in   │ ....
" line │ ( ) ( ) ( ( ) ) ( )
" out  │     1   2 3     4
function! s:nextp()
    return s:search(s:count, s:opening, 'W')
endfunction

" find `count` last closing delimiter (multi line)
" in   │               ....
" line │ ( ) ( ) ( ( ) ) ( )
" out  │   4   3     2 1
function! s:lastp(...)
    return s:search(s:count, s:closing, 'bW')
endfunction

" find `count` next opening tag delimiter (multi line)
" in   │ .........
" line │ <a> </a> <b> </b> <c> <d> </d> </c> <e> </e>
" out  │          1        2   3             4
function! s:nextt()
    return s:search(s:count, '<\a', 'W')
endfunction

" find `count` last closing tag delimiter (multi line)
" in   │                                    .........
" line │ <a> </a> <b> </b> <c> <d> </d> </c> <e> </e>
" out  │     4        3            2    1
function! s:lastt()
    return s:search(s:count, '</\a', 'bW')
endfunction

" match selectors
" ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

" select pair of delimiters around cursor (multi line, no seeking)
" select to the right if cursor is on a delimiter
" cursor  │   ....
" line    │ ' ' b ' '
" matcher │   └───┘
" TODO: similar to s:selecta, move them together, or can they even be merged
" somehow?
function! s:select(direction)
    let oldpos = getpos('.')

    if a:direction == '>'
        let [s:sl, s:sc, s:el, s:ec, err] = s:findSeparators('bcW', 'W', s:opening, s:closing)
        let message = 'select 1'
    else
        let [s:el, s:ec, s:sl, s:sc, err] = s:findSeparators('cW', 'bW', s:closing, s:opening)
        let message = 'select 2'
    endif

    if err > 0
        call setpos('.', oldpos)
        return s:fail(message)
    endif
endfunction

function! s:findSeparators(flags1, flags2, opening, closing)
    let [sl, sc] = searchpos(a:opening, a:flags1)
    if sc == 0 " no match to the left
        return [0, 0, 0, 0, s:fail('findSeparators opening')]
    endif
    let [el, ec] = searchpos(a:closing, a:flags2)
    if ec == 0 " no match to the right
        return [0, 0, 0, 0, s:fail('findSeparators closing')]
    endif
    return [sl, sc, el, ec, 0]
endfunction

" select pair of delimiters around cursor (multi line, no seeking)
function! s:seekselect()
    let [rl, rc] = searchpos(s:opening, '', line('.'))
    if rl > 0 " delim r found after cursor in line
        let [s:sl, s:sc] = searchpos(s:opening, 'b', line('.'))
        if s:sl > 0 " delim found before r in line
            let [s:el, s:ec] = [rl, rc]
            return
        endif
        " no delim before cursor in line
        let [s:el, s:ec] = searchpos(s:opening, '', line('.'))
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
        return s:fail('seekselect 1')
    endif

    " no delim found after cursor in line
    let [ll, lc] = searchpos(s:opening, 'bc', line('.'))
    if ll > 0 " delim l found before cursor in line
        let [s:sl, s:sc] = searchpos(s:opening, 'b', line('.'))
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
        return s:fail('seekselect 2')
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
        return s:fail('seekselect 3')
    endif

    " no delim found after cursor
    let [s:el, s:ec] = searchpos(s:opening, 'bW')
    let [s:sl, s:sc] = searchpos(s:opening, 'bW')
    if s:sl > 0 && s:el > 0 " match found before cursor
        return
    endif
    return s:fail('seekselect 4')
endfunction

" pair matcher (works across multiple lines, no seeking)
" cursor   │   .....
" line     │ ( ( a ) )
" modifier │ │ └─1─┘ │
"          │ └── 2 ──┘
" TODO: that image is wrong, right? there is no count involved here
function! s:selectp()
    " try to select pair
    silent! execute 'normal! va' . s:opening
    let [s:el, s:ec] = getpos('.')[1:2]
    silent! normal! o
    let [s:sl, s:sc] = getpos('.')[1:2]
    silent! normal! v

    if s:sc == s:ec && s:sl == s:el
        return s:fail('selectp')
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
        return s:fail('seekselectp count')
    endif
    let s:count = 1

    let [s:sl, s:sc] = searchpos(opening, '', line('.'))
    if s:sc > 0 " found opening to the right in line
        return s:selectp()
    endif

    let [s:sl, s:sc] = searchpos(closing, 'b', line('.'))
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

    return s:fail('seekselect')
endfunction

" tag pair matcher (works across multiple lines, supports seeking)
function! s:seekselectt()
    return s:seekselectp('<\a', '</\a', 't')
endfunction

" TODO: comment, reorder selecta functions
" foo(a, b(x), c)

" TODO: grow
" TODO: skip quotes?
" TODO: can't select argument from d: x(a(b)c)d
function! s:selecta(direction)
    let oldpos = getpos('.')

    if a:direction ==# '>'
        let [s:sl, s:sc, s:el, s:ec, err] = s:findArg('W', 'bW', '[({[]', '[]})]')
        let message = 'selecta 1'
    elseif a:direction ==# '<'
        let [s:el, s:ec, s:sl, s:sc, err] = s:findArg('bW', 'W', '[]})]', '[({[]')
        let message = 'selecta 2'
    elseif a:direction ==# '^'
        let [s:sl, s:sc, s:el, s:ec, err] = s:findArgUp('W', 'bW', '[({[]', '[]})]')
        let message = 'selecta 3'
    else
        return s:fail('selecta')
    endif

    if err > 0
        call setpos('.', oldpos)
        return s:fail(message)
    endif
endfunction

" TODO: merge with findArg? clean up!
function! s:findArgUp(flags1, flags2, opening, closing)
    let oldpos = getpos('.')
    let char = s:getchar()

    if char =~# a:closing " started on closing
        let [el, ec, err] = s:findArgBoundary(a:flags1, a:flags1, a:opening, a:closing)
        if err > 0 " no opening found
            return [0, 0, 0, 0, s:fail('findArg 1', a:)]
        endif

        if char =~# a:opening || char ==# ',' " started on opening or separator
            let [sl, sc] = oldpos[1:2] " use old position as start
            return [sl, sc, el, ec, 0]
        endif

        call setpos('.', oldpos) " return to old position
    endif

    " find start to the left
    let [sl, sc, err] = s:findArgBoundary('bcW', 'bW', a:closing, a:opening)
    if err > 0
        return [0, 0, 0, 0, s:fail('findArg 2')]
    endif

    return [sl, sc, el, ec, 0]
endfunction

function! s:findArg(flags1, flags2, opening, closing)
    let oldpos = getpos('.')
    let char = s:getchar()

    if char =~# a:closing " started on closing
        let [el, ec] = oldpos[1:2] " use old position as end
    else " find end to the right
        let [el, ec, err] = s:findArgBoundary(a:flags1, a:flags1, a:opening, a:closing)
        if err > 0 " no opening found
            return [0, 0, 0, 0, s:fail('findArg 1', a:)]
        endif

        if char =~# a:opening || char ==# ',' " started on opening or separator
            let [sl, sc] = oldpos[1:2] " use old position as start
            return [sl, sc, el, ec, 0]
        endif

        call setpos('.', oldpos) " return to old position
    endif

    " find start to the left
    let [sl, sc, err] = s:findArgBoundary(a:flags2, a:flags2, a:closing, a:opening)
    if err > 0
        return [0, 0, 0, 0, s:fail('findArg 2')]
    endif

    return [sl, sc, el, ec, 0]
endfunction

function! s:findArgBoundary(flags1, flags2, skip, finish)
    let tl = 0
    let [rl, rc] = searchpos('[]{(,)}[]', a:flags1)
    while 1
        if rl == 0
            return [0, 0, s:fail('findArgBoundary 1', a:)]
        endif

        let char = s:getchar()
        if char ==# ','
            if tl == 0
                let [tl, tc] = [rl, rc]
            endif
        elseif char =~# a:finish
            if tl > 0
                return [tl, tc, 0]
            endif
            return [rl, rc, 0]
        elseif char =~# a:skip
            silent! normal! %
        else
            return [0, 0, s:fail('findArgBoundary 2')]
        endif
        let [rl, rc] = searchpos('[]{(,)}[]', a:flags2)
    endwhile
endfunction

" TODO: support counts to select bigger arguments of outer functions
" TODO: select last argument if found in line, but no next in line
function! s:seekselecta()
    " TODO: use count here
    " try find count-1'th closing, call selecta with new direction '^' (up)
    " selecta('^') on opening or closing should not select inside, but find
    " surrounding argument
    if s:count > 1
        if s:getchar() =~# '[]})]'
            let [cnt, message] = [s:count - 2, 'seekselecta 1']
        else
            let [cnt, message] = [s:count - 1, 'seekselecta 2']
        endif
        if s:search(cnt, '[]})]', 'W') > 0
            return s:fail('seekselecta count')
        endif
        if s:selecta('^') == 0
            return
        endif
        return s:fail('seekselecta count select')
    endif

    if s:selecta('>') == 0
        return
    endif

    if s:nextselecta(line('.')) == 0
        return
    endif

    if s:lastselecta(line('.')) == 0
        return
    endif

    if s:nextselecta() == 0
        return
    endif

    if s:lastselecta() == 0
        return
    endif

    return s:fail('seekselecta seek')
endfunction

" TODO: document parameter list for all functions with ...
" optional stopline
function! s:nextselecta(...)
    let stopline = a:0 > 0 ? a:1 : 0

    if s:search(s:count, '[,({[]', 'W', stopline) > 0 " no start found
        return s:fail('nextselecta 1')
    endif

    let char = s:getchar()
    if s:selecta('>') == 0 " argument found
        return
    endif

    if char !=# ',' " start wasn't on comma
        return s:fail('nextselecta 2')
    endif

    call setpos('.', s:oldpos)
    if s:search(s:count, '[({[]', 'W', stopline) > 0 " no start found
        return s:fail('nextselecta 3')
    endif

    if s:selecta('>') == 0 " argument found
        return
    endif

    return s:fail('nextselecta 4')
endfunction

" TODO: extract variables for '[]}),]' etc?
function! s:lastselecta(...)
    let stopline = a:0 > 0 ? a:1 : 0
    if s:mapmode ==# 'x' " if visual mode
        " move cursor to end of selection
        silent! normal! `>
    endif

    " special case to handle vala when invoked on a comma
    if s:getchar() ==# ',' && s:newSelection()
        if s:selecta('<') == 0
            return
        endif
    endif

    if s:search(s:count, '[]}),]', 'bW', stopline) > 0 " no start found
        return s:fail('lastselecta 1')
    endif

    let char = s:getchar()
    if s:selecta('<') == 0 " argument found
        return
    endif

    if char !=# ',' " start wasn't on comma
        return s:fail('lastselecta 2')
    endif

    call setpos('.', s:oldpos)
    if s:search(s:count, '[]})]', 'bW', stopline) > 0 " no start found
        return s:fail('lastselecta 3')
    endif

    if s:selecta('<') == 0 " argument found
        return
    endif

    return s:fail('lastselecta 4')
endfunction

" TODO: remove
" TODO: comment
" TODO: test again when selecting only one separator
" TODO: combine with selecta to nextselecta that behaves like in seekselecta:
"   search for , or opening, try selecta
"   if selecta failed from , search for opening and try selecta again
"   (effectively skipping top level commas)

" selects the current cursor position (useful to test modifiers)
function! s:position()
    let [s:sl, s:sc] = getpos('.')[1:2]
    let [s:el, s:ec] = [s:sl, s:sc]
endfunction

" selection modifiers
" ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

" drop delimiters left and right
" remove last line of multiline selection if it consists of whitespace only
" in   │   ┌─────┐
" line │ a .  b  . c
" out  │    └───┘
function! s:drop()
    call cursor(s:sl, s:sc)
    if searchpos('\S', 'nW', line('.'))[0] == 0
        " if only whitespace after cursor
        let s:sLinewise = 1
    endif
    silent! execute "normal! 1 "
    let [s:sl, s:sc] = getpos('.')[1:2]

    call cursor(s:el, s:ec)
    if s:sl < s:el && searchpos('\S', 'bnW', line('.'))[0] == 0
        " if only whitespace in front of cursor
        let s:eLinewise = 1
        " move to end of line above
        normal! -$
    else
        " one character back
        silent! execute "normal! \<BS>"
    endif
    let [s:el, s:ec] = getpos('.')[1:2]
endfunction

" drop right delimiter
" in   │   ┌─────┐
" line │ a . b c . d
" out  │   └────┘
function! s:dropr()
    let s:ec -= 1
endfunction

" select inner tag delimiters
" in   │   ┌──────────┐
" line │ a <b>  c  </b> c
" out  │     └─────┘
function! s:innert()
    call cursor(s:sl, s:sc)
    call searchpos('>', 'W')
    let [s:sl, s:sc] = getpos('.')[1:2]
    call cursor(s:el, s:ec)
    call searchpos('<', 'bW')
    let [s:el, s:ec] = getpos('.')[1:2]
endfunction

" drop delimiters and whitespace left and right
" fall back to drop when only whitespace is inside
" in   │   ┌─────┐   │   ┌──┐
" line │ a . b c . d │ a .  . d
" out  │     └─┘     │    └┘
function! s:shrink()
    call cursor(s:el, s:ec)
    let [s:el, s:ec] = searchpos('\S', 'b', s:sl)
    if s:ec <= s:sc && s:el <= s:sl
        " fall back to drop when there's only whitespace in between
        return s:drop()
    endif
    call cursor(s:sl, s:sc)
    let [s:sl, s:sc] = searchpos('\S', '', s:el)
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

" grows selection on repeated invocations by increasing s:count
" TODO: delay? remember that growing was requested, try normal selection,
" compare with initial selection. only if they match, increase count and try
" again
" TODO: growing too far resets the visual selection, fix it
function! s:grow()
    if s:mapmode == 'o'
        return
    endif
    if s:newSelection()
        return
    endif
    if [s:ldelimiters, s:lmatchers] != [s:delimiters, s:matchers] " different invocation
        return
    endif

    " increase s:count to grow selection
    let s:count = s:count + 1
endfunction

function! s:newSelection()
    if !exists('s:lsl') " no previous invocation
        return 1
    endif
    if getpos("'<")[1:2] != [s:lsl, s:lsc] " selection start changed
        return 1
    endif
    if getpos("'>")[1:2] != [s:lel, s:lec] " selection end changed
        return 1
    endif

    return
endfunction

" doubles the count (used for `iN'`)
function! s:double()
    let s:count = s:count * 2
endfunction

" TODO: comment
function! s:getchar()
    return getline('.')[col('.')-1]
endfunction

" TODO: comment
function! s:search(...)
    if a:0 == 4
        let [cnt, pattern, flags, stopline] = [a:1, a:2, a:3, a:4]
    elseif a:0 == 3
        let [cnt, pattern, flags, stopline] = [a:1, a:2, a:3, 0]
    else
        return s:fail('search arguments')
    endif

    for _ in range(cnt)
        let line = searchpos(pattern, flags, stopline)[0]
        if line == 0 " not enough found
            return s:fail('search')
        endif
    endfor
endfunction

function! s:fail(...)
    if a:0 == 2
        call s:debug('fail ' . a:1 . ' ' . string(a:2))
    else
        call s:debug('fail ' . a:1)
    endif
    return 1
endfunction

function! s:debug(message)
    " echom a:message
endfunction

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
