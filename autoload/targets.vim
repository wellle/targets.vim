" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license

" save cpoptions
let s:save_cpoptions = &cpoptions
set cpo&vim

" called once when loaded
function! s:setup()
    let s:argOpening   = get(g:, 'targets_argOpening', '[([]')
    let s:argClosing   = get(g:, 'targets_argClosing', '[])]')
    let s:argSeparator = get(g:, 'targets_argSeparator', ',')
    let s:argOpeningS  = s:argOpening  . '\|' . s:argSeparator
    let s:argClosingS  = s:argClosing  . '\|' . s:argSeparator
    let s:argOuter     = s:argOpening  . '\|' . s:argClosing
    let s:argAll       = s:argOpeningS . '\|' . s:argClosing
    let s:none         = 'a^' " matches nothing

    let s:rangeScores = {}
    let ranges = split(get(g:, 'targets_seekRanges',
                \ 'cr cb cB lc ac Ac lr rr ll lb ar ab lB Ar aB Ab AB rb al rB Al bb aa bB Aa BB AA'))
    let rangesN = len(ranges)
    let i = 0
    while i < rangesN
        let s:rangeScores[ranges[i]] = rangesN - i
        let i = i + 1
    endwhile

    let s:rangeJumps = {}
    let ranges = split(get(g:, 'targets_jumpRanges', 'bb bB BB aa Aa AA'))
    let rangesN = len(ranges)
    let i = 0
    while i < rangesN
        let s:rangeJumps[ranges[i]] = 1
        let i = i + 1
    endwhile

    " currently undocumented, currently not supposed to be user defined
    " but could be used to disable 'smart' quote skipping
    " some technicalities: inverse mapping from quote reps to quote arg reps
    " quote rep '102' means:
    "   1: even number of quotation character left from cursor
    "   0: no quotation char under cursor
    "   2: even number (but nonzero) of quote chars right of cursor
    " arg rep 'r1l' means:
    "   r: select to right (l: to left; n: not at all)
    "   1: single speed (each quote char starts one text object)
    "      (2: double speed, skip pseudo quotes)
    "   l: skip first quote when going left ("last" quote objects)
    "      (r: skip once when going right ("next"); b: both; n: none)
    let s:quoteDirsConf = get(g:, 'targets_quoteDirs', {
                \ 'r1n': ['001', '201', '100', '102'],
                \ 'r1l': ['010', '012', '111', '210', '212'],
                \ 'r2n': ['101'],
                \ 'r2l': ['011', '211'],
                \ 'r2b': ['000'],
                \ 'l2r': ['110', '112'],
                \ 'n2b': ['002', '200', '202'],
                \ })

    " args in order: dir, rate, skipL, skipR, error
    let s:quoteArgs = {
                \ 'r1n': ['>', 1, 0, 0, ''],
                \ 'r1l': ['>', 1, 1, 0, ''],
                \ 'r2n': ['>', 2, 0, 0, ''],
                \ 'r2l': ['>', 2, 1, 0, ''],
                \ 'r2b': ['>', 2, 1, 1, ''],
                \ 'l2r': ['<', 2, 0, 1, ''],
                \ 'n2b': [ '', 2, 1, 1, ''],
                \ }
    let s:quoteDirs = {}
    for key in keys(s:quoteArgs)
        let args = s:quoteArgs[key]
        for rep in get(s:quoteDirsConf, key, [])
            let s:quoteDirs[rep] = args
        endfor
    endfor
endfunction

call s:setup()

" a:count is unused here, but added for consistency with targets#x
function! targets#o(trigger, count)
    call s:init()
    let context = {
        \ 'mapmode': 'o',
        \ 'oldpos': getpos('.'),
        \ }

    let [delimiter, which, modifier] = split(a:trigger, '\zs')
    let [target, rawTarget] = s:findTarget(context, delimiter, which, modifier, v:count1)
    if target.state().isInvalid()
        call s:abortMatch(context, '#o: ' . target.error)
        return s:cleanUp()
    endif
    call s:handleTarget(context, target, rawTarget)
    call s:clearCommandLine()
    call s:prepareRepeat(delimiter, which, modifier)
    call s:cleanUp()
endfunction

" 'e' is for expression; return expression to execute, used for visual
" mappings to not break non-targets visual mappings
" and for operator pending mode as well if possible to speed up plugin loading
" time
function! targets#e(modifier, original)
    let mode = mode(1)
    if mode ==? 'v' " visual mode, from xnoremap
        let prefix = "call targets#x('"
    elseif mode ==# 'no' " operator pending, from onoremap
        let prefix = "call targets#o('"
    else
        return a:original
    endif

    let char1 = nr2char(getchar())
    let [delimiter, which, chars] = [char1, 'c', char1]
    let i = 0
    while i < 2
        if g:targets_nl[i] ==# delimiter
            " delimiter was which, get another char for delimiter
            let char2 = nr2char(getchar())
            let [delimiter, which, chars] = [char2, 'nl'[i], chars . char2]
            break
        endif
        let i = i + 1
    endwhile

    let [_, _, _, err] = s:getDelimiters(delimiter)
    if err
        return a:original . chars
    endif

    if delimiter ==# "'"
        let delimiter = "''"
    endif

    let s:call = prefix . delimiter . which . a:modifier . "', " . v:count1 . ")"
    " indirectly (but silently) call targets#do below
    return "@(targets)"
endfunction

" gets called via the @(targets) mapping from above
function! targets#do()
    exe s:call
endfunction

" 'x' is for visual (as in :xnoremap, not in select mode)
function! targets#x(trigger, count)
    call s:initX(a:trigger)
    let context = {
        \ 'mapmode': 'x',
        \ 'oldpos': getpos('.'),
        \ }

    let [delimiter, which, modifier] = split(a:trigger, '\zs')
    let [target, rawTarget] = s:findTarget(context, delimiter, which, modifier, a:count)
    if target.state().isInvalid()
        call s:abortMatch(context, '#x: ' . target.error)
        return s:cleanUp()
    endif
    if s:handleTarget(context, target, rawTarget) == 0
        let s:lastTrigger = a:trigger
        let s:lastTarget = target
        let s:lastRawTarget = rawTarget
    endif
    call s:cleanUp()
endfunction

" initialize script local variables for the current matching
function! s:init()
    let s:newSelection = 1
    let s:shouldGrow = 1

    let s:selection = &selection " remember 'selection' setting
    let &selection = 'inclusive' " and set it to inclusive

    let s:virtualedit = &virtualedit " remember 'virtualedit' setting
    let &virtualedit = ''            " and set it to default

    let s:whichwrap = &whichwrap " remember 'whichwrap' setting
    let &whichwrap = 'b,s' " and set it to default
endfunction

" save old visual selection to detect new selections and reselect on fail
function! s:initX(trigger)
    call s:init()

    let s:visualTarget = targets#target#fromVisualSelection(s:selection)

    " reselect, save mode and go back to normal mode
    normal! gv
    if mode() ==# 'V'
        let s:visualTarget.linewise = 1
        normal! V
    else
        normal! v
    endif

    let s:newSelection = s:isNewSelection()
    let s:shouldGrow = s:shouldGrow(a:trigger)
endfunction

" clean up script variables after match
function! s:cleanUp()
    " reset remembered settings
    let &selection = s:selection
    let &virtualedit = s:virtualedit
    let &whichwrap = s:whichwrap
endfunction

function! s:findTarget(context, delimiter, which, modifier, count)
    let [kind, s:opening, s:closing, err] = s:getDelimiters(a:delimiter)
    if err
        let errorTarget = targets#target#withError("failed to find delimiter")
        return [errorTarget, errorTarget]
    endif

    let view = winsaveview()
    let rawTarget = s:findRawTarget(a:context, kind, a:which, a:count)
    let target = s:modifyTarget(rawTarget, kind, a:modifier)
    call winrestview(view)
    return [target, rawTarget]
endfunction

function! s:findRawTarget(context, kind, which, count)
    if a:kind ==# 'p'
        if a:which ==# 'c'
            return s:seekselectp(a:count + s:grow(a:context))
        elseif a:which ==# 'n'
            if s:search(a:count, s:opening, 'W') > 0
                return targets#target#withError('findRawTarget pn')
            endif
            return s:selectp()
        elseif a:which ==# 'l'
            if s:search(a:count, s:closing, 'bW') > 0
                return targets#target#withError('findRawTarget pl')
            endif
            return s:selectp()
        else
            return targets#target#withError('findRawTarget p')
        endif

    elseif a:kind ==# 'q'
        let [dir, rate, skipL, skipR, error] = s:quoteDir()
        if error !=# ''
            return targets#target#withError('findRawTarget quoteDir')
        endif
        if a:which ==# 'c'
            return s:seekselect(dir, rate - skipL, rate - skipR)
        elseif a:which ==# 'n'
            return s:nextselect(a:count * rate - skipR)
        elseif a:which ==# 'l'
            return s:lastselect(a:count * rate - skipL)
        else
            return targets#target#withError('findRawTarget q: ' . a:which)
        endif

    elseif a:kind ==# 's'
        if a:which ==# 'c'
            return s:seekselect('>', 1, 1)
        elseif a:which ==# 'n'
            return s:nextselect(a:count)
        elseif a:which ==# 'l'
            return s:lastselect(a:count)
        else
            return targets#target#withError('findRawTarget s')
        endif

    elseif a:kind ==# 't'
        if a:which ==# 'c'
            return s:seekselectp(a:count + s:grow(a:context), '<\a', '</\a', 't')
        elseif a:which ==# 'n'
            if s:search(a:count, '<\a', 'W') > 0
                return targets#target#withError('findRawTarget tn')
            endif
            return s:selectp()
        elseif a:which ==# 'l'
            if s:search(a:count, '</\a\zs', 'bW') > 0
                return targets#target#withError('findRawTarget tn')
            endif
            return s:selectp()
        else
            return targets#target#withError('findRawTarget t')
        endif

    elseif a:kind ==# 'a'
        if a:which ==# 'c'
            return s:seekselecta(a:context, a:count + s:grow(a:context))
        elseif a:which ==# 'n'
            return s:nextselecta(a:context, a:count)
        elseif a:which ==# 'l'
            return s:lastselecta(a:context, a:count)
        else
            return targets#target#withError('findRawTarget a')
        endif
    endif

    return targets#target#withError('findRawTarget kind')
endfunction

function! s:modifyTarget(target, kind, modifier)
    if a:target.state().isInvalid()
        return targets#target#withError('modifyTarget invalid: ' . a:target.error)
    endif
    let target = a:target.copy()

    if a:kind ==# 'p'
        if a:modifier ==# 'i'
            return s:drop(target)
        elseif a:modifier ==# 'a'
            return target
        elseif a:modifier ==# 'I'
            return s:shrink(target)
        elseif a:modifier ==# 'A'
            return s:expand(target)
        else
            return targets#target#withError('modifyTarget p')
        endif

    elseif a:kind ==# 'q'
        if a:modifier ==# 'i'
            return s:drop(target)
        elseif a:modifier ==# 'a'
            return target
        elseif a:modifier ==# 'I'
            return s:shrink(target)
        elseif a:modifier ==# 'A'
            return s:expand(target)
        else
            return targets#target#withError('modifyTarget q')
        endif

    elseif a:kind ==# 's'
        if a:modifier ==# 'i'
            return s:drop(target)
        elseif a:modifier ==# 'a'
            return s:dropr(target)
        elseif a:modifier ==# 'I'
            return s:shrink(target)
        elseif a:modifier ==# 'A'
            return s:expands(target)
        else
            return targets#target#withError('modifyTarget s')
        endif

    elseif a:kind ==# 't'
        if a:modifier ==# 'i'
            let target = s:innert(target)
            return s:drop(target)
        elseif a:modifier ==# 'a'
            return target
        elseif a:modifier ==# 'I'
            let target = s:innert(target)
            return s:shrink(target)
        elseif a:modifier ==# 'A'
            return s:expand(target)
        else
            return targets#target#withError('modifyTarget t')
        endif

    elseif a:kind ==# 'a'
        if a:modifier ==# 'i'
            return s:drop(target)
        elseif a:modifier ==# 'a'
            return s:dropa(target)
        elseif a:modifier ==# 'I'
            return s:shrink(target)
        elseif a:modifier ==# 'A'
            return s:expand(target)
        else
            return targets#target#withError('modifyTarget a')
        endif
    endif

    return targets#target#withError('modifyTarget kind')
endfunction

function! s:getDelimiters(trigger)
    " create cache
    if !exists('s:delimiterCache')
        let s:delimiterCache = {}
    endif

    " check cache
    if has_key(s:delimiterCache, a:trigger)
        let [kind, opening, closing] = s:delimiterCache[a:trigger]
        return [kind, opening, closing, 0]
    endif

    let [kind, rawOpening, rawClosing, err] = s:getRawDelimiters(a:trigger)
    if err > 0
        return [0, 0, 0, err]
    endif

    let opening = s:modifyDelimiter(kind, rawOpening)
    let closing = s:modifyDelimiter(kind, rawClosing)

    " write to cache
    let s:delimiterCache[a:trigger] = [kind, opening, closing]

    return [kind, opening, closing, 0]
endfunction

function! s:getRawDelimiters(trigger)
    " check more specific ones first for #145
    if a:trigger ==# g:targets_tagTrigger
        return ['t', 't', 0, 0]
    elseif a:trigger ==# g:targets_argTrigger
        return ['a', 0, 0, 0]
    endif

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

    return [0, 0, 0, 1]
endfunction

function! s:modifyDelimiter(kind, delimiter)
    let delimiter = escape(a:delimiter, '.~\$')
    if a:kind !=# 'q' || &quoteescape ==# ''
        return delimiter
    endif

    let escapedqe = escape(&quoteescape, ']^-\')
    let lookbehind = '[' . escapedqe . ']'
    if v:version >= 704
        return lookbehind . '\@1<!' . delimiter
    else
        return lookbehind . '\@<!'  . delimiter
    endif
endfunction

" return 0 if the selection changed since the last invocation. used for
" growing
function! s:isNewSelection()
    " no previous invocation or target
    if !exists('s:lastTarget')
        return 1
    endif

    " selection changed
    if s:lastTarget != s:visualTarget
        return 1
    endif

    return 0
endfunction

function! s:shouldGrow(trigger)
    if s:newSelection
        return 0
    endif

    if !exists('s:lastTrigger')
        return 0
    endif

    if s:lastTrigger != a:trigger
        return 0
    endif

    return 1
endfunction

" clear the commandline to hide targets function calls
function! s:clearCommandLine()
    echo
endfunction

" handle the match by either selecting or aborting it
function! s:handleTarget(context, target, rawTarget)
    if a:target.state().isInvalid()
        return s:abortMatch(a:context, 'handleTarget')
    elseif a:target.state().isEmpty()
        return s:handleEmptyMatch(a:context, a:target)
    else
        return s:selectTarget(a:context, a:target, a:rawTarget)
    endif
endfunction

" select a proper match
function! s:selectTarget(context, target, rawTarget)
    " add old position to jump list
    if s:addToJumplist(a:context, a:rawTarget)
        call setpos('.', a:context.oldpos)
        normal! m'
    endif

    call s:selectRegion(a:target)
endfunction

function! s:addToJumplist(context, target)
    let min = line('w0')
    let max = line('w$')
    let range = a:target.range(a:context.oldpos, min, max)
    return get(s:rangeJumps, range)
endfunction

" visually select a given match. used for match or old selection
function! s:selectRegion(target)
    " visually select the target
    call a:target.select()

    " if selection should be exclusive, expand selection
    if s:selection ==# 'exclusive'
        normal! l
    endif
endfunction

" empty matches can't visually be selected
" most operators would like to move to the end delimiter
" for change or delete, insert temporary character that will be operated on
function! s:handleEmptyMatch(context, target)
    if a:context.mapmode !=# 'o' || v:operator !~# "^[cd]$"
        return s:abortMatch(a:context, 'handleEmptyMatch')
    endif

    " move cursor to delimiter after zero width match
    call a:target.cursorS()

    let eventignore = &eventignore " remember setting
    let &eventignore = 'all' " disable auto commands

    " insert single space and visually select it
    silent! execute "normal! i \<Esc>v"

    let &eventignore = eventignore " restore setting
endfunction

" abort when no match was found
function! s:abortMatch(context, message)
    " get into normal mode and beep
    if !exists("*getcmdwintype") || getcmdwintype() ==# ""
        call feedkeys("\<C-\>\<C-N>\<Esc>", 'n')
    endif

    call s:prepareReselect(a:context)
    call setpos('.', a:context.oldpos)

    " undo partial command
    call s:triggerUndo()
    " trigger reselect if called from xmap
    call s:triggerReselect(a:context)

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
function! s:prepareReselect(context)
    if a:context.mapmode ==# 'x'
        call s:selectRegion(s:visualTarget)
    endif
endfunction

" feed keys to reselect the last visual selection if called with mapmode x
function! s:triggerReselect(context)
    if a:context.mapmode ==# 'x'
        call feedkeys("gv", 'n')
    endif
endfunction

" set up repeat.vim for older Vim versions
function! s:prepareRepeat(delimiter, which, modifier)
    if v:version >= 704 " skip recent versions
        return
    endif

    if v:operator ==# 'y' && match(&cpoptions, 'y') ==# -1 " skip yank unless set up
        return
    endif

    let cmd = v:operator . a:modifier
    if a:which !=# 'c'
        let cmd .= a:which
    endif
    let cmd .= a:delimiter
    if v:operator ==# 'c'
        let cmd .= "\<C-r>.\<ESC>"
    endif

    silent! call repeat#set(cmd, v:count)
endfunction

" undo last operation if it created a new undo position
function! targets#undo(lastseq)
    if undotree().seq_cur > a:lastseq
        silent! execute "normal! u"
    endif
endfunction

" returns [dir, rate, skipL, skipR, error]
function! s:quoteDir()
    let line = getline('.')
    let col = col('.')

    " cut line in left of, on and right of cursor
    let left = col > 1 ? line[:col-2] : ""
    let cursor = line[col-1]
    let right = line[col :]

    " how many delitimers left, on and right of cursor
    let lc = s:count(s:opening, left)
    let cc = s:count(s:opening, cursor)
    let rc = s:count(s:opening, right)

    " truncate counts
    let lc = lc == 0 ? 0 : lc % 2 == 0 ? 2 : 1
    let rc = rc == 0 ? 0 : rc % 2 == 0 ? 2 : 1

    let key = lc . cc . rc
    let defaultValues = ['', 0, 0, 0, 'bad key: ' . key]
    let [dir, rate, skipL, skipR, error] = get(s:quoteDirs, key, defaultValues)
    return [dir, rate, skipL, skipR, error]
endfunction

function! s:nextselect(count)
    " echom 'nextselect' a:count
    if s:search(a:count, s:opening, 'W') > 0
        return targets#target#withError('nextselect')
    endif

    return s:select('>')
endfunction

function! s:lastselect(count)
    " echom 'lastselect' a:count
    if s:search(a:count, s:closing, 'bW') > 0
        return targets#target#withError('lastselect')
    endif

    return s:select('<')
endfunction

" match selectors
" ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

" select pair of delimiters around cursor (multi line, no seeking)
" select to the right if cursor is on a delimiter
" cursor  │   ....
" line    │ ' ' b ' '
" matcher │   └───┘
function! s:select(direction)
    if a:direction ==# ''
        return targets#target#withError('select without direction')
    elseif a:direction ==# '>'
        let [sl, sc] = searchpos(s:opening, 'bcW') " search left for opening
        let [el, ec] = searchpos(s:closing, 'W')   " then right for closing
        return targets#target#fromValues(sl, sc, el, ec)
    else
        let [el, ec] = searchpos(s:closing, 'cW') " search right for closing
        let [sl, sc] = searchpos(s:opening, 'bW') " then left for opening
        return targets#target#fromValues(sl, sc, el, ec)
    endif
endfunction

" select pair of delimiters around cursor (multi line, supports seeking)
function! s:seekselect(dir, countL, countR)
    " echom 'seekselect' a:dir 'countL' a:countL 'countR' a:countR
    let min = line('w0')
    let max = line('w$')
    let oldpos = getpos('.')

    let around = s:select(a:dir)

    call setpos('.', oldpos)

    let last = s:lastselect(a:countL)

    call setpos('.', oldpos)

    let next = s:nextselect(a:countR)

    return s:bestSeekTarget([around, next, last], oldpos, min, max, 'seekselect')
endfunction

" select a pair around the cursor
" args (count=1, trigger=s:opening)
function! s:selectp(...)
    let cnt     = a:0 >= 1 ? a:1 : 1
    let trigger = a:0 >= 2 ? a:2 : s:opening

    " try to select pair
    silent! execute 'keepjumps normal! v' . cnt . 'a' . trigger
    let [el, ec] = getpos('.')[1:2]
    silent! normal! o
    let [sl, sc] = getpos('.')[1:2]
    silent! normal! v

    if sc == ec && sl == el
        return targets#target#withError('selectp')
    endif

    return targets#target#fromValues(sl, sc, el, ec)
endfunction

" pair matcher (works across multiple lines, supports seeking)
" cursor   │   .....
" line     │ ( ( a ) )
" modifier │ │ └─1─┘ │
"          │ └── 2 ──┘
" args (count, opening=s:opening, closing=s:closing, trigger=s:closing)
function! s:seekselectp(...)
    let cnt     =            a:1 " required
    let opening = a:0 >= 2 ? a:2 : s:opening
    let closing = a:0 >= 3 ? a:3 : s:closing
    let trigger = a:0 >= 4 ? a:4 : s:closing

    let min = line('w0')
    let max = line('w$')
    let oldpos = getpos('.')

    let around = s:selectp(cnt, trigger)

    if cnt > 1 " don't seek with count
        return around
    endif

    let targets = [around]

    call setpos('.', oldpos)
    if s:search(1, s:closing, 'bW') == 0
        let targets = add(targets, s:selectp())
    endif

    call setpos('.', oldpos)
    if s:search(1, s:opening, 'W') == 0
        let targets = add(targets, s:selectp())
    endif

    return s:bestSeekTarget(targets, oldpos, min, max, 'seekselectp')
endfunction

" select an argument around the cursor
" parameter direction decides where to select when invoked on a separator:
"   '>' select to the right (default)
"   '<' select to the left (used when selecting or skipping to the left)
"   '^' select up (surrounding argument, used for growing)
function! s:selecta(direction)
    let oldpos = getpos('.')

    let [opening, closing] = [s:argOpening, s:argClosing]
    if a:direction ==# '^'
        let [sl, sc, el, ec, err] = s:findArg(a:direction, 'W', 'bcW', 'bW', opening, closing)
        let message = 'selecta 1'
    elseif a:direction ==# '>'
        let [sl, sc, el, ec, err] = s:findArg(a:direction, 'W', 'bW', 'bW', opening, closing)
        let message = 'selecta 2'
    elseif a:direction ==# '<' " like '>', but backwards
        let [el, ec, sl, sc, err] = s:findArg(a:direction, 'bW', 'W', 'W', closing, opening)
        let message = 'selecta 3'
    else
        return targets#target#withError('selecta')
    endif

    if err > 0
        call setpos('.', oldpos)
        return targets#target#withError(message)
    endif

    return targets#target#fromValues(sl, sc, el, ec)
endfunction

" find an argument around the cursor given a direction (see s:selecta)
" uses flags1 to search for end to the right; flags1 and flags2 to search for
" start to the left
function! s:findArg(direction, flags1, flags2, flags3, opening, closing)
    let oldpos = getpos('.')
    let char = s:getchar()
    let separator = s:argSeparator

    if char =~# a:closing && a:direction !=# '^' " started on closing, but not up
        let [el, ec] = oldpos[1:2] " use old position as end
    else " find end to the right
        let [el, ec, err] = s:findArgBoundary(a:flags1, a:flags1, a:opening, a:closing)
        if err > 0 " no closing found
            return [0, 0, 0, 0, s:fail('findArg 1', a:)]
        endif

        let separator = s:argSeparator
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
" separator=s:argSeparator, cnt=2)
" return (line, column, err)
function! s:findArgBoundary(...)
    let flags1    =            a:1 " required
    let flags2    =            a:2
    let skip      =            a:3
    let finish    =            a:4
    let all       = a:0 >= 5 ? a:5 : s:argAll
    let separator = a:0 >= 6 ? a:6 : s:argSeparator
    let cnt       = a:0 >= 7 ? a:7 : 1

    let [tl, rl, rc] = [0, 0, 0]
    for _ in range(cnt)
        let [rl, rc] = searchpos(all, flags1)
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
                silent! keepjumps normal! %
            else
                return [0, 0, s:fail('findArgBoundary 2')]
            endif
            let [rl, rc] = searchpos(all, flags2)
        endwhile
    endfor

    return [rl, rc, 0]
endfunction

" selects and argument, supports growing and seeking
function! s:seekselecta(context, count)
    if a:count > 1
        if s:getchar() =~# s:argClosing
            let [cnt, message] = [a:count - 2, 'seekselecta 1']
        else
            let [cnt, message] = [a:count - 1, 'seekselecta 2']
        endif
        " find cnt closing while skipping matched openings
        let [opening, closing] = [s:argOpening, s:argClosing]
        if s:findArgBoundary('W', 'W', opening, closing, s:argOuter, s:none, cnt)[2] > 0
            return targets#target#withError(message . ' count')
        endif
        return s:selecta('^')
    endif

    let min = line('w0')
    let max = line('w$')
    let oldpos = getpos('.')

    let around = s:selecta('>')

    if a:count > 1 " don't seek with count
        return around
    endif

    call setpos('.', oldpos)

    let last = s:lastselecta(a:context)

    call setpos('.', oldpos)

    let next = s:nextselecta(a:context)

    return s:bestSeekTarget([around, next, last], oldpos, min, max, 'seekselecta')
endfunction

" try to select a next argument, supports count and optional stopline
" args (context, count=1, stopline=0)
function! s:nextselecta(...)
    let context  =            a:1 " required
    let cnt      = a:0 >= 2 ? a:2 : 1
    let stopline = a:0 >= 3 ? a:3 : 0

    if s:search(cnt, s:argOpeningS, 'W', stopline) > 0 " no start found
        return targets#target#withError('nextselecta 1')
    endif

    let char = s:getchar()
    let target = s:selecta('>')
    if target.state().isValid()
        return target
    endif

    if char !~# s:argSeparator " start wasn't on comma
        return targets#target#withError('nextselecta 2')
    endif

    call setpos('.', context.oldpos)
    let opening = s:argOpening
    if s:search(cnt, opening, 'W', stopline) > 0 " no start found
        return targets#target#withError('nextselecta 3')
    endif

    let target = s:selecta('>')
    if target.state().isValid()
        return target
    endif

    return targets#target#withError('nextselecta 4')
endfunction

" try to select a last argument, supports count and optional stopline
" args (context, count=1, stopline=0)
function! s:lastselecta(...)
    let context  =            a:1 " required
    let cnt      = a:0 >= 2 ? a:2 : 1
    let stopline = a:0 >= 3 ? a:3 : 0

    " special case to handle vala when invoked on a separator
    let separator = s:argSeparator
    if s:getchar() =~# separator && s:newSelection
        let target = s:selecta('<')
        if target.state().isValid()
            return target
        endif
    endif

    if s:search(cnt, s:argClosingS, 'bW', stopline) > 0 " no start found
        return targets#target#withError('lastselecta 1')
    endif

    let char = s:getchar()
    let target = s:selecta('<')
    if target.state().isValid()
        return target
    endif

    if char !~# separator " start wasn't on separator
        return targets#target#withError('lastselecta 2')
    endif

    call setpos('.', context.oldpos)
    let closing = s:argClosing
    if s:search(cnt, closing, 'bW', stopline) > 0 " no start found
        return targets#target#withError('lastselecta 3')
    endif

    let target = s:selecta('<')
    if target.state().isValid()
        return target
    endif

    return targets#target#withError('lastselecta 4')
endfunction

" select best of given targets according to s:rangeScores
" detects for each given target what range type it has, depending on the
" relative positions of the start and end of the target relative to the cursor
" position and the currently visible lines

" The possibly relative positions are:
"   c - on cursor position
"   l - left of cursor in current line
"   r - right of cursor in current line
"   a - above cursor on screen
"   b - below cursor on screen
"   A - above cursor off screen
"   B - below cursor off screen

" All possibly ranges are listed below, denoted by two characters: one for the
" relative start and for the relative end position each of the target. For
" example, `lr` means "from left of cursor to right of cursor in cursor line".

" Next to each range type is a pictogram of an example. They are made of these
" symbols:
"    .  - current cursor position
"   ( ) - start and end of target
"    /  - line break before and after cursor line
"    |  - screen edge between hidden and visible lines

" ranges on cursor:
"   cr   |  /  () /  |   starting on cursor, current line
"   cb   |  /  (  /) |   starting on cursor, multiline down, on screen
"   cB   |  /  (  /  |)  starting on cursor, multiline down, partially off screen
"   lc   |  / ()  /  |   ending on cursor, current line
"   ac   | (/  )  /  |   ending on cursor, multiline up, on screen
"   Ac  (|  /  )  /  |   ending on cursor, multiline up, partially off screen

" ranges around cursor:
"   lr   |  / (.) /  |   around cursor, current line
"   lb   |  / (.  /) |   around cursor, multiline down, on screen
"   ar   | (/  .) /  |   around cursor, multiline up, on screen
"   ab   | (/  .  /) |   around cursor, multiline both, on screen
"   lB   |  / (.  /  |)  around cursor, multiline down, partially off screen
"   Ar  (|  /  .) /  |   around cursor, multiline up, partially off screen
"   aB   | (/  .  /  |)  around cursor, multiline both, partially off screen bottom
"   Ab  (|  /  .  /) |   around cursor, multiline both, partially off screen top
"   AB  (|  /  .  /  |)  around cursor, multiline both, partially off screen both

" ranges after (right of/below) cursor
"   rr   |  /  .()/  |   after cursor, current line
"   rb   |  /  .( /) |   after cursor, multiline, on screen
"   rB   |  /  .( /  |)  after cursor, multiline, partially off screen
"   bb   |  /  .  /()|   after cursor below, on screen
"   bB   |  /  .  /( |)  after cursor below, partially off screen
"   BB   |  /  .  /  |() after cursor below, off screen

" ranges before (left of/above) cursor
"   ll   |  /().  /  |   before cursor, current line
"   al   | (/ ).  /  |   before cursor, multiline, on screen
"   Al  (|  / ).  /  |   before cursor, multiline, partially off screen
"   aa   |()/  .  /  |   before cursor above, on screen
"   Aa  (| )/  .  /  |   before cursor above, partially off screen
"   AA ()|  /  .  /  |   before cursor above, off screen

"     A  a  l r  b  B  relative positions
"      └───────────┘   visible screen
"         └─────┘      current line

function! s:bestSeekTarget(targets, oldpos, min, max, message)
    let bestScore = 0
    for target in a:targets
        let range = target.range(a:oldpos, a:min, a:max)
        let score = get(s:rangeScores, range)
        if bestScore < score
            let bestScore = score
            let best = target
        endif
    endfor

    if bestScore > 0
        return best
    endif

    return targets#target#withError(a:message)
endfunction

" selection modifiers
" ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

" drop delimiters left and right
" remove last line of multiline selection if it consists of whitespace only
" in   │   ┌─────┐
" line │ a .  b  . c
" out  │    └───┘
function! s:drop(target)
    if a:target.state().isInvalid()
        return a:target
    endif

    let [sLinewise, eLinewise] = [0, 0]
    call a:target.cursorS()
    if searchpos('\S', 'nW', line('.'))[0] == 0
        " if only whitespace after cursor
        let sLinewise = 1
    endif
    silent! execute "normal! 1 "
    call a:target.getposS()

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
    call a:target.getposE()
    let a:target.linewise = sLinewise && eLinewise
    return a:target
endfunction

" drop right delimiter
" in   │   ┌─────┐
" line │ a . b c . d
" out  │   └────┘
function! s:dropr(target)
    call a:target.cursorE()
    silent! execute "normal! \<BS>"
    call a:target.getposE()
    return a:target
endfunction

" drop an argument separator (like a comma), prefer the right one, fall back
" to the left (one on first argument)
" in   │ ┌───┐ ┌───┐        ┌───┐        ┌───┐
" line │ ( x ) ( x , a ) (a , x , b) ( a , x )
" out  │  └─┘    └──┘       └──┘        └──┘
function! s:dropa(target)
    let startOpening = a:target.getcharS() !~# s:argSeparator
    let endOpening   = a:target.getcharE() !~# s:argSeparator

    if startOpening
        if endOpening
            " ( x ) select space on both sides
            return s:drop(a:target)
        else
            " ( x , a ) select separator and space after
            call a:target.cursorS()
            call a:target.searchposS('\S', '', a:target.el)
            return s:expand(a:target, '>')
        endif
    else
        if !endOpening
            " (a , x , b) select leading separator, no surrounding space
            return s:dropr(a:target)
        else
            " ( a , x ) select separator and space before
            call a:target.cursorE()
            call a:target.searchposE('\S', 'b', a:target.sl)
            return s:expand(a:target, '<')
        endif
    endif
endfunction

" select inner tag delimiters
" in   │   ┌──────────┐
" line │ a <b>  c  </b> c
" out  │     └─────┘
function! s:innert(target)
    call a:target.cursorS()
    call a:target.searchposS('>', 'W')
    call a:target.cursorE()
    call a:target.searchposE('<', 'bW')
    return a:target
endfunction

" drop delimiters and whitespace left and right
" fall back to drop when only whitespace is inside
" in   │   ┌─────┐   │   ┌──┐
" line │ a . b c . d │ a .  . d
" out  │     └─┘     │    └┘
function! s:shrink(target)
    if a:target.state().isInvalid()
        return a:target
    endif

    call a:target.cursorE()
    call a:target.searchposE('\S', 'b', a:target.sl)
    if a:target.state().isInvalidOrEmpty()
        " fall back to drop when there's only whitespace in between
        return s:drop(a:target)
    else
        call a:target.cursorS()
        call a:target.searchposS('\S', '', a:target.el)
    endif
    return a:target
endfunction

" expand selection by some whitespace
" in   │   ┌───┐   │   ┌───┐  │  ┌───┐  │ ┌───┐
" line │ a . b . c │ a . b .c │ a. c .c │ . a .c
" out  │   └────┘  │  └────┘  │  └───┘  │└────┘
" args (target, direction=<try right, then left>)
function! s:expand(...)
    let target = a:1

    if a:0 == 1 || a:2 ==# '>'
        call target.cursorE()
        let [line, column] = searchpos('\S\|$', '', line('.'))
        if line > 0 && column-1 > target.ec
            " non whitespace or EOL after trailing whitespace found
            " not counting whitespace directly after end
            call target.setE(line, column-1)
            return target
        endif
    endif

    if a:0 == 1 || a:2 ==# '<'
        call target.cursorS()
        let [line, column] = searchpos('\S', 'b', line('.'))
        if line > 0
            " non whitespace before leading whitespace found
            call target.setS(line, column+1)
            return target
        endif
        " only whitespace in front of start
        " include all leading whitespace from beginning of line
        let target.sc = 1
    endif

    return target
endfunction

" expand separator selection by one whitespace if there are two
" in   │   ┌───┐   │  ┌───┐   │   ┌───┐  │  ┌───┐  │ ┌───┐
" line │ a . b . c │ a. b . c │ a . b .c │ a. c .c │ . a .c
" out  │   └────┘  │  └───┘   │   └───┘  │  └───┘  │ └───┘
" args (target, direction=<try right, then left>)
function! s:expands(target)
    call a:target.cursorE()
    let [eline, ecolumn] = searchpos('\S\|$', '', line('.'))
    if eline > 0 && ecolumn-1 > a:target.ec

        call a:target.cursorS()
        let [sline, scolumn] = searchpos('\S', 'b', line('.'))
        if sline > 0 && scolumn+1 < a:target.sc

            call a:target.setE(eline, ecolumn-1)
            return a:target
        endif
    endif

    return a:target
endfunction

" return 1 if count should be increased by one to grow selection on repeated
" invocations
function! s:grow(context)
    if a:context.mapmode ==# 'o' || !s:shouldGrow
        return 0
    endif

    " move cursor to boundary of last raw target
    " to handle expansion in tight boundaries like (((x)))
    call s:lastRawTarget.cursorE()

    return 1
endfunction

" returns the character under the cursor
function! s:getchar()
    return getline('.')[col('.')-1]
endfunction

" search for pattern using flags and a count, optional stopline
" args (cnt, pattern, flags, stopline=0)
function! s:search(...)
    let cnt      =            a:1 " required
    let pattern  =            a:2
    let flags    =            a:3
    let stopline = a:0 >= 4 ? a:4 : 0

    for _ in range(cnt)
        let line = searchpos(pattern, flags, stopline)[0]
        if line == 0 " not enough found
            return s:fail('search')
        endif
    endfor
endfunction

function! s:count(char, text)
    return len(split(a:text, a:char, 1)) - 1
endfunction

" return 1 and send a message to s:debug
" args (message, parameters=nil)
function! s:fail(...)
    let message = 'fail ' . a:1
    let message .= a:0 >= 2 ? ' ' . string(a:2) : ''
    call s:debug(message)
    return 1
endfunction

function! s:print(...)
    echom string(a:)
endfunction

" useful for debugging
function! s:debug(message)
    " echom a:message
endfunction

" reset cpoptions
let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
