" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license
" Updated: 2014-08-21
" Version: 0.3.0

" save cpoptions
let s:save_cpoptions = &cpoptions
set cpo&vim

" called once when loaded
function! s:setup()
    let [s:a, s:i, s:A, s:I] = split(g:targets_aiAI, '\zs')
    let [s:n, s:l, s:N, s:L] = split(g:targets_nlNL, '\zs')

    let s:argOpeningS = g:targets_argOpening . '\|' . g:targets_argSeparator
    let s:argClosingS = g:targets_argClosing . '\|' . g:targets_argSeparator
    let s:argOuter    = g:targets_argOpening . '\|' . g:targets_argClosing
    let s:argAll      = s:argOpeningS        . '\|' . g:targets_argClosing
    let s:none        = 'a^' " matches nothing
endfunction

call s:setup()

function! targets#o(trigger)
    call s:init('o')
    let [match, err] = s:findMatch(a:trigger, v:count1)
    if err
        return s:cleanUp()
    endif
    call s:handleMatch(match)
    call s:clearCommandLine()
    call s:cleanUp()
endfunction

function! targets#e(modifier)
    if mode() !=? 'v'
        return a:modifier
    endif

    " TODO: wrap getchar()? handle complicated return values
    let [delimiter, which] = [nr2char(getchar()), 'c']
    for nlNL in split(g:targets_nlNL, '\zs')
        if nlNL ==# delimiter
            " delimiter was which, get another char for delimiter
            let [delimiter, which] = [nr2char(getchar()), delimiter]
        endif
    endfor

    if delimiter ==# "'"
        let delimiter = "''"
    endif

    return "\<Esc>:\<C-U>call targets#x('" . delimiter . which . a:modifier . "', " . v:count1 . ")\<CR>"
endfunction

function! s:getWhich(char)
    if a:char ==# s:n
        return ['n', 0]
    elseif a:char ==# s:l
        return ['l', 0]
    elseif a:char ==# s:N
        return ['N', 0]
    elseif a:char ==# s:L
        return ['L', 0]
    else
        return [0, 1]
    endif
endfunction

function! targets#x(trigger, count)
    call s:init('x')
    call s:saveVisualSelection()
    let [match, err] = s:findMatch(a:trigger, a:count)
    if err
        return s:cleanUp()
    endif
    if s:handleMatch(match) == 0
        call s:saveState()
    endif
    call s:cleanUp()
endfunction

function! s:findMatch(trigger, count)
    let [delimiter, which, modifier] = split(a:trigger, '\zs')
    let [kind, s:opening, s:closing, err] = s:getDelimiters(delimiter)
    if err
        return [0, s:fail("failed to find delimiter")]
    endif

    let view = winsaveview()
    call s:findObject(kind, which, a:count)
    call s:saveRawSelection()
    let match = [[s:sl, s:sc], [s:el, s:ec]]
    let [match, err] = s:modifyMatch(match, kind, modifier)
    call winrestview(view)
    return [match, 0]
endfunction

" remember last raw selection, before applying modifiers
function! s:saveRawSelection()
    let [s:rsl, s:rsc, s:rel, s:rec] = [s:sl, s:sc, s:el, s:ec]
endfunction

" TODO: move down
" TODO: return [[[a, b], [c, d]], err]
function! s:modifyMatch(match, kind, modifier)
    if a:kind ==# 'p'
        if a:modifier ==# s:i
            return s:drop()
        elseif a:modifier ==# s:a
            return [a:match, 0]
        elseif a:modifier ==# s:I
            return s:shrink()
        elseif a:modifier ==# s:A
            return s:expand()
        else
            return [0, s:fail('modifyMatch p')]
        endif

    elseif a:kind ==# 'q'
        if a:modifier ==# s:i
            return s:drop()
        elseif a:modifier ==# s:a
            return [a:match, 0]
        elseif a:modifier ==# s:I
            return s:shrink()
        elseif a:modifier ==# s:A
            return s:expand()
        else
            return [0, s:fail('modifyMatch q')]
        endif

    elseif a:kind ==# 's'
        if a:modifier ==# s:i
            return s:drop()
        elseif a:modifier ==# s:a
            return s:dropr()
        elseif a:modifier ==# s:I
            return s:shrink()
        elseif a:modifier ==# s:A
            return s:expand()
        else
            return [0, s:fail('modifyMatch s')]
        endif

    elseif a:kind ==# 't'
        if a:modifier ==# s:i
            let [match, err] = s:innert()
            return s:drop()
        elseif a:modifier ==# s:a
            return [a:match, 0]
        elseif a:modifier ==# s:I
            let [match, err] = s:innert()
            return s:shrink()
        elseif a:modifier ==# s:A
            return s:expand()
        else
            return [0, s:fail('modifyMatch t')]
        endif

    elseif a:kind ==# s:a
        if a:modifier ==# s:i
            return s:drop()
        elseif a:modifier ==# s:a
            return s:dropa()
        elseif a:modifier ==# s:I
            return s:shrink()
        elseif a:modifier ==# s:A
            return s:expand()
        else
            return [0, s:fail('modifyMatch a')]
        endif
    endif

    return [0, s:fail('modifyMatch kind')]
endfunction

" TODO: move down
function! s:findObject(kind, which, count)
    if a:kind ==# 'p'
        if a:which ==# 'c'
            call s:seekselectp(a:count)
        elseif a:which ==# 'n'
            call s:nextp(a:count)
            call s:selectp()
        elseif a:which ==# 'l'
            call s:lastp(a:count)
            call s:selectp()
        else
            " TODO: fail
        endif

    elseif a:kind ==# 'q'
        if a:which ==# 'c'
            call s:quote()
            call s:seekselect()
        elseif a:which ==# 'n'
            call s:quote()
            call s:nextselect(a:count)
        elseif a:which ==# 'l'
            call s:quote()
            call s:lastselect(a:count)
        elseif a:which ==# 'N'
            call s:quote()
            call s:nextselect(a:count * 2)
        elseif a:which ==# 'L'
            call s:quote()
            call s:lastselect(a:count * 2)
        else
            " TODO: fail
        endif

    elseif a:kind ==# 's'
        if a:which ==# 'c'
            call s:seekselect()
        elseif a:which ==# 'n'
            call s:nextselect(a:count)
        elseif a:which ==# 'l'
            call s:lastselect(a:count)
        elseif a:which ==# 'N'
            call s:nextselect(a:count * 2)
        elseif a:which ==# 'L'
            call s:lastselect(a:count * 2)
        else
            " TODO: fail
        endif

    elseif a:kind ==# 't'
        if a:which ==# 'c'
            call s:seekselectt(a:count)
        elseif a:which ==# 'n'
            call s:nextt(a:count)
            call s:selectp()
        elseif a:which ==# 'l'
            call s:lastt(a:count)
            call s:selectp()
        else
            " TODO: fail
        endif

    elseif a:kind ==# 'a'
        if a:which ==# 'c'
            call s:seekselecta(a:count)
        elseif a:which ==# 'n'
            call s:nextselecta(a:count)
        elseif a:which ==# 'l'
            call s:lastselecta(a:count)
        else
            " TODO: fail
        endif

    endif
endfunction

function! s:getDelimiters(trigger)
    let [kind, rawOpening, rawClosing, err] = s:getRawDelimiters(a:trigger)
    if err > 0
        return [0, 0, 0, err]
    endif

    let opening = escape(rawOpening, '".~\$')
    let closing = escape(rawClosing, '".~\$')
    return [kind, opening, closing, 0]
endfunction

" TODO: use =~# instead of iterating
function! s:getRawDelimiters(trigger)
    " TODO: cache
    for pair in split(g:targets_pairs)
        for trigger in split(pair, '\zs')
            if trigger ==# a:trigger
                return ['p', pair[0], pair[1], 0]
            endif
        endfor
    endfor

    for quote in split(g:targets_quotes)
        for trigger in split(quote, '\zs')
            if trigger ==# a:trigger
                return ['q', quote[0], quote[0], 0]
            endif
        endfor
    endfor

    for separator in split(g:targets_separators)
        for trigger in split(separator, '\zs')
            if trigger ==# a:trigger
                return ['s', separator[0], separator[0], 0]
            endif
        endfor
    endfor

    if a:trigger ==# 't'
        return ['t', 't', 0, 0] " TODO: set tag patterns here and remove special tag functions?
    elseif a:trigger ==# 'a'
        return ['a', 0, 0, 0]
    else
        return [0, 0, 0, 1]
    endif
endfunction

" initialize script local variables for the current matching
function! s:init(mapmode)
    let s:mapmode = a:mapmode
    let [s:rsl, s:rsc, s:rel, s:rec] = [0, 0, 0, 0]
    let [s:sl, s:sc, s:el, s:ec] = [0, 0, 0, 0]
    let [s:sLinewise, s:eLinewise] = [0, 0]
    let s:oldpos = getpos('.')
    let s:newSelection = 1

    let s:selection = &selection " remember 'selection' setting
    let &selection = 'inclusive' " and set it to inclusive
endfunction

" clean up script variables after match
function! s:cleanUp()
    let &selection = s:selection " reset 'selection' setting
endfunction

" save old visual selection to detect new selections and reselect on fail
function! s:saveVisualSelection()
    let [s:vsl, s:vsc] = getpos("'<")[1:2]
    let [s:vel, s:vec] = getpos("'>")[1:2]

    " reselect, save mode and go back to normal mode
    normal! gv
    let s:vmode = mode()
    silent! execute "normal! \<C-\>\<C-N>"

    let s:newSelection = s:isNewSelection()
endfunction

" return 0 if the selection changed since the last invocation. used for
" growing
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

" remember last selection and last raw selection
function! s:saveState()
    " XXX: remember raw trigger
    let [s:lrsl, s:lrsc, s:lrel, s:lrec] = [s:rsl, s:rsc, s:rel, s:rec]

    let s:lmode = mode()

    " back to normal mode, save positions, reselect
    silent! execute "normal! \<C-\>\<C-N>"
    let [s:lsl, s:lsc] = getpos("'<")[1:2]
    let [s:lel, s:lec] = getpos("'>")[1:2]
    normal! gv
endfunction

" clear the commandline to hide targets function calls
function! s:clearCommandLine()
    echo
endfunction

" handle the match by either selecting or aborting it
function! s:handleMatch(match)
    let target = targets#target#fromArray(a:match)
    if s:sl == 0 || s:el == 0
        return s:abortMatch('handleMatch 1')
    elseif s:sl < s:el
        return s:selectTarget(target)
    elseif s:sl > s:el
        return s:abortMatch('handleMatch 2')
    elseif s:sc == s:ec + 1
        return s:handleEmptyMatch()
    elseif s:sc > s:ec
        return s:abortMatch('handleMatch 3')
    else
        return s:selectTarget(target)
    endif
endfunction

" select a proper match
function! s:selectTarget(target)
    " add old position to jump list
    call setpos('.', s:oldpos)
    normal! m'

    let a:target.linewise = s:sLinewise && s:eLinewise
    call s:selectRegion(a:target)
endfunction

" visually select a given match. used for match or old selection
function! s:selectRegion(target)
    " visually select the target
    call cursor(a:target.s())

    if a:target.linewise
        silent! normal! V
    else
        silent! normal! v
    endif

    call cursor(a:target.e())

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
    if s:mapmode ==# 'x'
        let target = targets#target#fromValues(s:vsl, s:vsc, s:vel, s:vec)
        let target.linewise = (s:vmode ==# 'V')
        call s:selectRegion(target)
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
" current problem: skipping v"an"an" doesn't work
" also va", van", val" doesn't capture the three correct quotes when issued on
" a quote character
function! s:quote()
    if s:getchar() !=# s:opening
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
endfunction

" find `count` next delimiter (multi line)
" in   │     ...
" line │  '  '  '  '
" out  │        1  2
function! s:nextselect(count)
    call s:prepareNext()

    if s:search(a:count, s:opening, 'W') > 0
        return s:fail('nextselect')
    endif

    return s:select('>')
endfunction

" find `count` last delimiter, move in front of it (multi line)
" in   │     ...
" line │  '  '  '  '
" out  │ 2  1
function! s:lastselect(count)
    " if started on closing, but not when skipping
    if !s:prepareLast() && s:getchar() ==# s:closing
        let [cnt, message] = [a:count - 1, 'lastselect 1']
    else
        let [cnt, message] = [a:count, 'lastselect 2']
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
function! s:nextp(count)
    call s:prepareNext()
    return s:search(a:count, s:opening, 'W')
endfunction

" find `count` last closing delimiter (multi line)
" in   │               ....
" line │ ( ) ( ) ( ( ) ) ( )
" out  │   4   3     2 1
function! s:lastp(count)
    call s:prepareLast()
    return s:search(a:count, s:closing, 'bW')
endfunction

" find `count` next opening tag delimiter (multi line)
" in   │ .........
" line │ <a> </a> <b> </b> <c> <d> </d> </c> <e> </e>
" out  │          1        2   3             4
function! s:nextt(count)
    call s:prepareNext()
    return s:search(a:count, '<\a', 'W')
endfunction

" find `count` last closing tag delimiter (multi line)
" in   │                                    .........
" line │ <a> </a> <b> </b> <c> <d> </d> </c> <e> </e>
" out  │     4        3            2    1
function! s:lastt(count)
    call s:prepareLast()
    return s:search(a:count, '</\a\zs', 'bW')
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

    if a:direction ==# '>'
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

" find separators around cursor by searching for opening with flags1 and for
" closing with flags2
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

" select a pair around the cursor
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
" cursor   │   .....
" line     │ ( ( a ) )
" modifier │ │ └─1─┘ │
"          │ └── 2 ──┘
" args (count, opening=s:opening, closing=s:closing, trigger=s:closing)
function! s:seekselectp(...)
    let cnt = a:1 + s:grow()

    if a:0 == 4
        let [opening, closing, trigger] = [a:2, a:3, a:4]
    else
        let [opening, closing, trigger] = [s:opening, s:closing, s:closing]
    endif

    " try to select around cursor
    silent! execute 'normal! v' . cnt . 'a' . trigger
    let [s:el, s:ec] = getpos('.')[1:2]
    silent! normal! o
    let [s:sl, s:sc] = getpos('.')[1:2]
    silent! normal! v

    if s:sc != s:ec || s:sl != s:el
        " found target around cursor
        let cnt = 1
        return
    endif

    if cnt > 1
        return s:fail('seekselectp count')
    endif
    let cnt = 1

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
function! s:seekselectt(count)
    return s:seekselectp(a:count, '<\a', '</\a', 't')
endfunction

" select an argument around the cursor
" parameter direction decides where to select when invoked on a separator:
"   '>' select to the right (default)
"   '<' select to the left (used when selecting or skipping to the left)
"   '^' select up (surrounding argument, used for growing)
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
endfunction

" find an argument around the cursor given a direction (see s:selecta)
" uses flags1 to search for end to the right; flags1 and flags2 to search for
" start to the left
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

" find arg boundary by search for `finish` or `separator` while skipping
" matching `skip`s
" example: find ',' or ')' while skipping a pair when finding '('
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

" selects and argument, supports growing and seeking
function! s:seekselecta(count)
    let cnt = a:count + s:grow()

    if cnt > 1
        if s:getchar() =~# g:targets_argClosing
            let [cnt, message] = [cnt - 2, 'seekselecta 1']
        else
            let [cnt, message] = [cnt - 1, 'seekselecta 2']
        endif
        " find cnt closing while skipping matched openings
        let [opening, closing] = [g:targets_argOpening, g:targets_argClosing]
        if s:findArgBoundary('W', 'W', opening, closing, s:argOuter, s:none, cnt)[2] > 0
            return s:fail(message . ' count')
        endif
        if s:selecta('^') == 0
            return
        endif
        return s:fail(message . ' select')
    endif

    if s:selecta('>') == 0
        return
    endif

    if s:nextselecta(cnt, line('.')) == 0
        return
    endif

    if s:lastselecta(cnt, line('.')) == 0
        return
    endif

    if s:nextselecta(cnt) == 0
        return
    endif

    if s:lastselecta(cnt) == 0
        return
    endif

    return s:fail('seekselecta seek')
endfunction

" try to select a next argument, supports count and optional stopline
" args (count, stopline=0) TODO: make count optional
function! s:nextselecta(...)
    call s:prepareNext()

    let cnt = a:1
    let stopline = a:0 > 1 ? a:2 : 0
    if s:search(cnt, s:argOpeningS, 'W', stopline) > 0 " no start found
        return s:fail('nextselecta 1')
    endif

    let char = s:getchar()
    if s:selecta('>') == 0 " argument found
        return
    endif

    if char !~# g:targets_argSeparator " start wasn't on comma
        return s:fail('nextselecta 2')
    endif

    call setpos('.', s:oldpos)
    let opening = g:targets_argOpening
    if s:search(cnt, opening, 'W', stopline) > 0 " no start found
        return s:fail('nextselecta 3')
    endif

    if s:selecta('>') == 0 " argument found
        return
    endif

    return s:fail('nextselecta 4')
endfunction

" try to select a last argument, supports count and optional stopline
" args (count, stopline=0) TODO: make count optional
function! s:lastselecta(...)
    call s:prepareLast()

    " special case to handle vala when invoked on a separator
    let separator = g:targets_argSeparator
    if s:getchar() =~# separator && s:newSelection
        if s:selecta('<') == 0
            return
        endif
    endif

    let cnt = a:1
    let stopline = a:0 > 1 ? a:2 : 0
    if s:search(cnt, s:argClosingS, 'bW', stopline) > 0 " no start found
        return s:fail('lastselecta 1')
    endif

    let char = s:getchar()
    if s:selecta('<') == 0 " argument found
        return
    endif

    if char !~# separator " start wasn't on separator
        return s:fail('lastselecta 2')
    endif

    call setpos('.', s:oldpos)
    let closing = g:targets_argClosing
    if s:search(cnt, closing, 'bW', stopline) > 0 " no start found
        return s:fail('lastselecta 3')
    endif

    if s:selecta('<') == 0 " argument found
        return
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
    return [[[s:sl, s:sc], [s:el, s:ec]], 0]
endfunction

" drop right delimiter
" in   │   ┌─────┐
" line │ a . b c . d
" out  │   └────┘
function! s:dropr()
    call cursor(s:el, s:ec)
    silent! execute "normal! \<BS>"
    let [s:el, s:ec] = getpos('.')[1:2]
    return [[[s:sl, s:sc], [s:el, s:ec]], 0]
endfunction

" drop an argument separator (like a comma), prefer the right one, fall back
" to the left (one on first argument)
" in   │ ┌───┐ ┌───┐        ┌───┐        ┌───┐
" line │ ( x ) ( x , a ) (a , x , b) ( a , x )
" out  │  └─┘    └──┘       └──┘        └──┘
function! s:dropa()
    let startOpening = s:getchar(s:sl, s:sc) !~# g:targets_argSeparator
    let endOpening   = s:getchar(s:el, s:ec) !~# g:targets_argSeparator

    if startOpening
        if endOpening
            " ( x ) select space on both sides
            return s:drop()
        else
            " ( x , a ) select separator and space after
            call cursor(s:sl, s:sc)
            let [s:sl, s:sc] = searchpos('\S', '', s:el)
            return s:expand('>')
        endif
    else
        if !endOpening
            " (a , x , b) select leading separator, no surrounding space
            return s:dropr()
        else
            " ( a , x ) select separator and space before
            call cursor(s:el, s:ec)
            let [s:el, s:ec] = searchpos('\S', 'b', s:sl)
            return s:expand('<')
        endif
    endif
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
    return [[[s:sl, s:sc], [s:el, s:ec]], 0]
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
    else
        call cursor(s:sl, s:sc)
        let [s:sl, s:sc] = searchpos('\S', '', s:el)
    endif
    return [[[s:sl, s:sc], [s:el, s:ec]], 0]
endfunction

" expand selection by some whitespace
" in   │   ┌───┐   │   ┌───┐  │  ┌───┐  │ ┌───┐
" line │ a . b . c │ a . b .c │ a. c .c │ . a .c
" out  │   └────┘  │  └────┘  │  └───┘  │└────┘
" args (direction=<try right, then left>)
function! s:expand(...)
    if a:0 == 0 || a:1 ==# '>'
        call cursor(s:el, s:ec)
        let [line, column] = searchpos('\S\|$', '', line('.'))
        if line > 0 && column-1 > s:ec
            " non whitespace or EOL after trailing whitespace found
            " not counting whitespace directly after end
            let [s:el, s:ec] = [line, column-1]
            return [[[s:sl, s:sc], [s:el, s:ec]], 0]
        endif
    endif

    if a:0 == 0 || a:1 ==# '<'
        call cursor(s:sl, s:sc)
        let [line, column] = searchpos('\S', 'b', line('.'))
        if line > 0
            " non whitespace before leading whitespace found
            let [s:sl, s:sc] = [line, column+1]
            return [[[s:sl, s:sc], [s:el, s:ec]], 0]
        endif
        " only whitespace in front of start
        " include all leading whitespace from beginning of line
        let s:sc = 1
    endif

    return [[[s:sl, s:sc], [s:el, s:ec]], 0]
endfunction

" return 1 if count should be increased by one to grow selection on repeated
" invocations
function! s:grow()
    if s:mapmode ==# 'o' || s:newSelection
        return 0
    endif
    " XXX: compare raw trigger
    " if [s:lopening, s:lclosing] != [s:opening, s:closing] " different invocation
    "     return 1
    " endif

    " move cursor back to last raw end of selection to avoid growing being
    " confused by last modifiers
    call s:prepareNext()

    return 1
endfunction

" if in visual mode, move cursor to start of last raw selection
" also used in s:grow to move to last raw end
function! s:prepareNext()
    if s:newSelection
        return
    endif
    if s:mapmode ==# 'x' && exists('s:lrsl') && s:lrsl > 0
        call setpos('.', [0, s:lrsl, s:lrsc, 0])
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

" returns the character under the cursor
" args (line=current, column=current)
function! s:getchar(...)
    if a:0 == 2
        let [l, c] = [a:1, a:2]
    else
        let [l, c] = ['.', col('.')]
    endif
    return getline(l)[c-1]
endfunction

" search for pattern using flags and a count, optional stopline
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

" return 1 and send a message to s:debug
" args (message, parameters=nil)
function! s:fail(...)
    if a:0 == 2
        call s:debug('fail ' . a:1 . ' ' . string(a:2))
    else
        call s:debug('fail ' . a:1)
    endif
    return 1
endfunction

" useful for debugging
function! s:debug(message)
    " echom a:message
endfunction

" reset cpoptions
let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
