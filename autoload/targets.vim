" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license
" Updated: 2014-06-14
" Version: 0.2.7

let s:save_cpoptions = &cpoptions
set cpo&vim

function! s:setup()
    let s:argOpeningS = g:targets_argOpening . '\|' . g:targets_argSeparator
    let s:argClosingS = g:targets_argClosing . '\|' . g:targets_argSeparator
    let s:argOuter    = g:targets_argOpening . '\|' . g:targets_argClosing
    let s:argAll      = s:argOpeningS        . '\|' . g:targets_argClosing
    let s:none        = 'a^' " matches nothing
endfunction

call s:setup()

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
    call s:saveVisualSelection()
    if s:handleMatch(a:matchers) == 0
        call s:saveState()
    endif
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
    let arguments = get(g:targets_mapArgs, a:trigger . chars, '')
    if arguments ==# ''
        return '\<Esc>'
    endif

    " exit visual mode and call targets#xmapCount
    return "\<Esc>:\<C-U>call targets#xmapCount(" . arguments . ", " . v:count1 . ")\<CR>"
endfunction

" initialize script local variables for the current matching
function! s:init(mapmode, delimiters, matchers, count)
    let [s:mapmode, s:delimiters, s:matchers, s:count] = [a:mapmode, a:delimiters, a:matchers,  a:count]
    let [s:rsl, s:rsc, s:rel, s:rec] = [0, 0, 0, 0]
    let [s:sl, s:sc, s:el, s:ec] = [0, 0, 0, 0]
    let [s:sLinewise, s:eLinewise] = [0, 0]
    let s:oldpos = getpos('.')
    let s:newSelection = 1

    let s:opening = escape(a:delimiters[0], '".~\$')
    if len(a:delimiters) == 2
        let s:closing = escape(a:delimiters[1], '".~\$')
    else
        let s:closing = s:opening
    endif

    let s:selection = &selection " remember 'selection' setting
    let &selection = 'inclusive' " and set it to inclusive
endfunction

function! s:saveVisualSelection()
    let [s:vsl, s:vsc] = getpos("'<")[1:2]
    let [s:vel, s:vec] = getpos("'>")[1:2]

    " reselect, save mode and go back to normal mode
    normal! gv
    let s:vmode = mode()
    silent! execute "normal! \<C-\>\<C-N>"

    let s:newSelection = s:isNewSelection()
endfunction

function! s:isNewSelection()
    if !exists('s:lsl') " no previous invocation
        return 1
    endif
    if [s:vsl, s:vsc] != [s:lsl, s:lsc] " selection start changed
        return 1
    endif
    if [s:vel, s:vec] != [s:lel, s:lec] " selection end changed
        return 1
    endif

    return 0
endfunction

" remember last raw selection, before applying modifiers
function! s:saveRawSelection()
    let [s:rsl, s:rsc, s:rel, s:rec] = [s:sl, s:sc, s:el, s:ec]
endfunction

" remember last selection and last raw selection
function! s:saveState()
    let [s:ldelimiters, s:lmatchers] = [s:delimiters, s:matchers]
    let [s:lrsl, s:lrsc, s:lrel, s:lrec] = [s:rsl, s:rsc, s:rel, s:rec]

    let s:lmode = mode()

    " back to normal mode, save positions, reselect
    silent! execute "normal! \<C-\>\<C-N>"
    let [s:lsl, s:lsc] = getpos("'<")[1:2]
    let [s:lel, s:lec] = getpos("'>")[1:2]
    normal! gv
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
        return s:abortMatch('handleMatch 1')
    elseif s:sl < s:el
        return s:selectMatch()
    elseif s:sl > s:el
        return s:abortMatch('handleMatch 2')
    elseif s:sc == s:ec + 1
        return s:handleEmptyMatch()
    elseif s:sc > s:ec
        return s:abortMatch('handleMatch 3')
    else
        return s:selectMatch()
    endif
endfunction

" select a proper match
function! s:selectMatch()
    " add old position to jump list
    call setpos('.', s:oldpos)
    normal! m'

    let linewise = s:sLinewise && s:eLinewise
    call s:selectRegion(linewise, s:sl, s:sc, s:el, s:ec)
endfunction

function! s:selectRegion(linewise, sl, sc, el, ec)
    " visually select the match
    call cursor(a:sl, a:sc)

    if a:linewise
        silent! normal! V
    else
        silent! normal! v
    endif

    call cursor(a:el, a:ec)

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
        return s:abortMatch('handleEmptyMatch')
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
function! s:abortMatch(message)
    call setpos('.', s:oldpos)
    " get into normal mode and beep
    call feedkeys("\<C-\>\<C-N>\<Esc>", 'n')

    call s:prepareReselect()
    " undo partial command
    call s:triggerUndo()
    " trigger reselect if called from xmap
    call s:triggerReselect()

    return s:fail(a:message)
endfunction

" feed keys to call undo after aborted operation and clear the command line
function! s:triggerUndo()
    if exists("*undotree")
        let undoseq = undotree().seq_cur
        call feedkeys(":call targets#undo(" . undoseq . ")\<CR>:echo\<CR>", 'n')
    endif
endfunction

" temporarily select original selection to reselect later
function! s:prepareReselect()
    let linewise = (s:vmode ==# 'V')
    call s:selectRegion(linewise, s:vsl, s:vsc, s:vel, s:vec)
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
" TODO: remove the quote function, add {seek,next,last}selectq
" current problem: skipping v"an"an" doesn't work
" also va", van", val" doesn't capture the three correct quotes when issued on
" a quote character
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
    call s:prepareNext()

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
function! s:lastselect()
    " if started on closing, but not when skipping
    if !s:prepareLast() && s:getchar() ==# s:closing
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
    call s:prepareNext()
    return s:search(s:count, s:opening, 'W')
endfunction

" find `count` last closing delimiter (multi line)
" in   │               ....
" line │ ( ) ( ) ( ( ) ) ( )
" out  │   4   3     2 1
function! s:lastp(...)
    call s:prepareLast()
    return s:search(s:count, s:closing, 'bW')
endfunction

" find `count` next opening tag delimiter (multi line)
" in   │ .........
" line │ <a> </a> <b> </b> <c> <d> </d> </c> <e> </e>
" out  │          1        2   3             4
function! s:nextt()
    call s:prepareNext()
    return s:search(s:count, '<\a', 'W')
endfunction

" find `count` last closing tag delimiter (multi line)
" in   │                                    .........
" line │ <a> </a> <b> </b> <c> <d> </d> </c> <e> </e>
" out  │     4        3            2    1
function! s:lastt()
    call s:prepareLast()
    return s:search(s:count, '</\a\zs', 'bW')
endfunction

" match selectors
" ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

" select pair of delimiters around cursor (multi line, no seeking)
" select to the right if cursor is on a delimiter
" cursor  │   ....
" line    │ ' ' b ' '
" matcher │   └───┘
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

    return s:saveRawSelection()
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

" select pair of delimiters around cursor (multi line, supports seeking)
function! s:seekselect()
    let [rl, rc] = searchpos(s:opening, '', line('.'))
    if rl > 0 " delim r found after cursor in line
        let [s:sl, s:sc] = searchpos(s:opening, 'b', line('.'))
        if s:sl > 0 " delim found before r in line
            let [s:el, s:ec] = [rl, rc]
            return s:saveRawSelection()
        endif
        " no delim before cursor in line
        let [s:el, s:ec] = searchpos(s:opening, '', line('.'))
        if s:el > 0 " delim found after r in line
            let [s:sl, s:sc] = [rl, rc]
            return s:saveRawSelection()
        endif
        " no delim found after r in line
        let [s:sl, s:sc] = searchpos(s:opening, 'bW')
        if s:sl > 0 " delim found before r
            let [s:el, s:ec] = [rl, rc]
            return s:saveRawSelection()
        endif
        " no delim found before r
        let [s:el, s:ec] = searchpos(s:opening, 'W')
        if s:el > 0 " delim found after r
            let [s:sl, s:sc] = [rl, rc]
            return s:saveRawSelection()
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
            return s:saveRawSelection()
        endif
        " no delim found before l in line
        let [s:el, s:ec] = searchpos(s:opening, 'W')
        if s:el > 0 " delim found after l
            let [s:sl, s:sc] = [ll, lc]
            return s:saveRawSelection()
        endif
        " no delim found after l
        let [s:sl, s:sc] = searchpos(s:opening, 'bW')
        if s:sl > 0 " delim found before l
            let [s:el, s:ec] = [ll, lc]
            return s:saveRawSelection()
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
            return s:saveRawSelection()
        endif
        " no delim found before r
        let [s:el, s:ec] = searchpos(s:opening, 'W')
        if s:el > 0 " delim found after r
            let [s:sl, s:sc] = [rl, rc]
            return s:saveRawSelection()
        endif
        " no delim found after r
        return s:fail('seekselect 3')
    endif

    " no delim found after cursor
    let [s:el, s:ec] = searchpos(s:opening, 'bW')
    let [s:sl, s:sc] = searchpos(s:opening, 'bW')
    if s:sl > 0 && s:el > 0 " match found before cursor
        return s:saveRawSelection()
    endif

    return s:fail('seekselect 4')
endfunction

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

    return s:saveRawSelection()
endfunction

" pair matcher (works across multiple lines, supports seeking)
" cursor   │   .....
" line     │ ( ( a ) )
" modifier │ │ └─1─┘ │
"          │ └── 2 ──┘
function! s:seekselectp(...)
    call s:grow()

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
        return s:saveRawSelection()
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

    return s:fail('seekselectp')
endfunction

" tag pair matcher (works across multiple lines, supports seeking)
function! s:seekselectt()
    return s:seekselectp('<\a', '</\a', 't')
endfunction

" TODO: comment, reorder selecta functions
function! s:selecta(direction)
    let oldpos = getpos('.')

    let [opening, closing] = [g:targets_argOpening, g:targets_argClosing]
    if a:direction ==# '^'
        let [s:sl, s:sc, s:el, s:ec, err] = s:findArg(a:direction, 'W', 'bcW', 'bW', opening, closing)
        let message = 'selecta 1'
    elseif a:direction ==# '>'
        let [s:sl, s:sc, s:el, s:ec, err] = s:findArg(a:direction, 'W', 'bW', 'bW', opening, closing)
        let message = 'selecta 2'
    elseif a:direction ==# '<' " like '>', but backwards
        let [s:el, s:ec, s:sl, s:sc, err] = s:findArg(a:direction, 'bW', 'W', 'W', closing, opening)
        let message = 'selecta 3'
    else
        return s:fail('selecta')
    endif

    if err > 0
        call setpos('.', oldpos)
        return s:fail(message)
    endif

    return s:saveRawSelection()
endfunction

function! s:findArg(direction, flags1, flags2, flags3, opening, closing)
    let oldpos = getpos('.')
    let char = s:getchar()
    let separator = g:targets_argSeparator

    if char =~# a:closing && a:direction !=# '^' " started on closing, but not up
        let [el, ec] = oldpos[1:2] " use old position as end
    else " find end to the right
        let [el, ec, err] = s:findArgBoundary(a:flags1, a:flags1, a:opening, a:closing)
        if err > 0 " no closing found
            return [0, 0, 0, 0, s:fail('findArg 1', a:)]
        endif

        let separator = g:targets_argSeparator
        if char =~# a:opening || char =~# separator " started on opening or separator
            let [sl, sc] = oldpos[1:2] " use old position as start
            return [sl, sc, el, ec, 0]
        endif

        call setpos('.', oldpos) " return to old position
    endif

    " find start to the left
    let [sl, sc, err] = s:findArgBoundary(a:flags2, a:flags3, a:closing, a:opening)
    if err > 0 " no opening found
        return [0, 0, 0, 0, s:fail('findArg 2')]
    endif

    return [sl, sc, el, ec, 0]
endfunction

" args (flags1, flags2, skip, finish, all=s:argAll,
" separator=g:targets_argSeparator, cnt=2)
" return (line, column, err)
function! s:findArgBoundary(...)
    let [flags1, flags2, skip, finish] = [a:1, a:2, a:3, a:4]
    if a:0 == 6
        let [all, separator, cnt] = [a:5, a:6, a:7]
    else
        let [all, separator, cnt] = [s:argAll, g:targets_argSeparator, 2]
    endif

    let tl = 0
    let [rl, rc] = searchpos(all, flags1)
    for _ in range(cnt)
        while 1
            if rl == 0
                return [0, 0, s:fail('findArgBoundary 1', a:)]
            endif

            let char = s:getchar()
            if char =~# separator
                if tl == 0
                    let [tl, tc] = [rl, rc]
                endif
            elseif char =~# finish
                if tl > 0
                    return [tl, tc, 0]
                endif
                break
            elseif char =~# skip
                silent! normal! %
            else
                return [0, 0, s:fail('findArgBoundary 2')]
            endif
            let [rl, rc] = searchpos(all, flags2)
        endwhile
    endfor

    return [rl, rc, 0]
endfunction

" TODO: prefer seeking into single line arguments over selecting multiline
" arguments around cursor (similar to how seekselect works)
" same for seekselectp
function! s:seekselecta()
    call s:grow()

    " TODO: v2aa on y doesn't work
    " (z, (x, (a), y))
    if s:count > 1
        if s:getchar() =~# g:targets_argClosing
            let [cnt, message] = [s:count - 2, 'seekselecta 1']
        else
            let [cnt, message] = [s:count - 1, 'seekselecta 2']
        endif
        " find cnt closing while skipping matched openings
        let [opening, closing] = [g:targets_argOpening, g:targets_argClosing]
        if s:findArgBoundary('W', 'W', opening, closing, s:argOuter, s:none, cnt)[2] > 0
        " if s:search(cnt, g:targets_argClosing, 'W') > 0
            return s:fail('seekselecta count')
        endif
        if s:selecta('^') == 0
            return s:saveRawSelection()
        endif
        return s:fail('seekselecta count select')
    endif

    if s:selecta('>') == 0
        return s:saveRawSelection()
    endif

    if s:nextselecta(line('.')) == 0
        return s:saveRawSelection()
    endif

    if s:lastselecta(line('.')) == 0
        return s:saveRawSelection()
    endif

    if s:nextselecta() == 0
        return s:saveRawSelection()
    endif

    if s:lastselecta() == 0
        return s:saveRawSelection()
    endif

    return s:fail('seekselecta seek')
endfunction

" TODO: document parameter list for all functions with ...
" optional stopline
function! s:nextselecta(...)
    call s:prepareNext()

    let stopline = a:0 > 0 ? a:1 : 0
    if s:search(s:count, s:argOpeningS, 'W', stopline) > 0 " no start found
        return s:fail('nextselecta 1')
    endif

    let char = s:getchar()
    if s:selecta('>') == 0 " argument found
        return s:saveRawSelection()
    endif

    if char !~# g:targets_argSeparator " start wasn't on comma
        return s:fail('nextselecta 2')
    endif

    call setpos('.', s:oldpos)
    let opening = g:targets_argOpening
    if s:search(s:count, opening, 'W', stopline) > 0 " no start found
        return s:fail('nextselecta 3')
    endif

    if s:selecta('>') == 0 " argument found
        return s:saveRawSelection()
    endif

    return s:fail('nextselecta 4')
endfunction

function! s:lastselecta(...)
    call s:prepareLast()

    " special case to handle vala when invoked on a separator
    let separator = g:targets_argSeparator
    if s:getchar() =~# separator && s:newSelection
        if s:selecta('<') == 0
            return s:saveRawSelection()
        endif
    endif

    let stopline = a:0 > 0 ? a:1 : 0
    if s:search(s:count, s:argClosingS, 'bW', stopline) > 0 " no start found
        return s:fail('lastselecta 1')
    endif

    let char = s:getchar()
    if s:selecta('<') == 0 " argument found
        return s:saveRawSelection()
    endif

    if char !~# separator " start wasn't on separator
        return s:fail('lastselecta 2')
    endif

    call setpos('.', s:oldpos)
    let closing = g:targets_argClosing
    if s:search(s:count, closing, 'bW', stopline) > 0 " no start found
        return s:fail('lastselecta 3')
    endif

    if s:selecta('<') == 0 " argument found
        return s:saveRawSelection()
    endif

    return s:fail('lastselecta 4')
endfunction

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
    call cursor(s:el, s:ec)
    silent! execute "normal! \<BS>"
    let [s:el, s:ec] = getpos('.')[1:2]
endfunction

" TODO: comment
function! s:dropa()
    if s:getchar(s:sl, s:sc) !~# g:targets_argSeparator
        call cursor(s:sl, s:sc)
        silent! execute "normal! 1 "
        let [s:sl, s:sc] = getpos('.')[1:2]

        if s:getchar(s:el, s:ec) =~# g:targets_argSeparator
            return s:expand()
        endif
    endif
    return s:dropr()
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
function! s:grow()
    if s:mapmode == 'o' || s:newSelection
        return
    endif
    if [s:ldelimiters, s:lmatchers] != [s:delimiters, s:matchers] " different invocation
        return
    endif

    call s:prepareNext()

    " increase s:count to grow selection
    let s:count = s:count + 1
endfunction

" if in visual mode, move cursor to start of last raw selection
" also used in s:grow to move to last raw end
function! s:prepareNext()
    if s:newSelection
        return
    endif
    if s:mapmode ==# 'x' && exists('s:lrsl') && s:lrsl > 0
        call setpos('.', [0, s:lrel, s:lrec, 0])
    endif
endfunction

" if in visual mode, move cursor to end of last raw selection
" returns whether or not the cursor was moved
function! s:prepareLast()
    if s:newSelection
        return
    endif
    if s:mapmode ==# 'x' && exists('s:lrel') && s:lrel > 0
        call setpos('.', [0, s:lrel, s:lrec, 0])
        return 1
    endif
endfunction

" doubles the count (used for `iN'`)
function! s:double()
    let s:count = s:count * 2
endfunction

" TODO: comment
function! s:getchar(...)
    if a:0 == 2
        let [l, c] = [a:1, a:2]
    else
        let [l, c] = ['.', col('.')]
    endif
    return getline(l)[c-1]
endfunction

" TODO: comment
" args (cnt, pattern, flags, stopline=0)
function! s:search(...)
    let [cnt, pattern, flags] = [a:1, a:2, a:3]
    if a:0 == 4
        let stopline = a:4
    elseif a:0 == 3
        let stopline = 0
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
