" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license

" save cpoptions
let s:save_cpoptions = &cpoptions
set cpo&vim

" called once when loaded
function! s:setup()
    " maps kind to factory constructor
    let s:registry = {
                \ 'pairs':      function('s:newFactoryP'),
                \ 'quotes':     function('s:newFactoryQ'),
                \ 'separators': function('s:newFactoryS'),
                \ 'arguments':  function('s:newFactoryA'),
                \ 'tags':       function('s:newFactoryT'),
                \ }

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

    let g:targets_multis = get(g:, 'targets_multis', {
                \ 'b': { 'pairs':  [['(', ')'], ['[', ']'], ['{', '}']], },
                \ 'q': { 'quotes': [["'"], ['"'], ['`']], },
                \ })
endfunction

" a:count is unused here, but added for consistency with targets#x
function! targets#o(trigger, count)
    let context = s:init('o')

    " TODO: include kind in trigger so we don't have to guess as much?
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

    if empty(s:getFactories(delimiter))
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
    let context = s:initX()

    let [delimiter, which, modifier] = split(a:trigger, '\zs')
    let [target, rawTarget] = s:findTarget(context, delimiter, which, modifier, a:count)
    if target.state().isInvalid()
        call s:abortMatch(context, '#x: ' . target.error)
        return s:cleanUp()
    endif
    if s:handleTarget(context, target, rawTarget) == 0
        let s:lastTarget = target
        let s:lastRawTarget = rawTarget
    endif
    call s:cleanUp()
endfunction

" initialize script local variables for the current matching
function! s:init(mapmode)
    let s:newSelection = 1

    let s:selection = &selection  " remember 'selection' setting
    let &selection  = 'inclusive' " and set it to inclusive

    let s:virtualedit = &virtualedit " remember 'virtualedit' setting
    let &virtualedit  = ''           " and set it to default

    let s:whichwrap = &whichwrap " remember 'whichwrap' setting
    let &whichwrap  = 'b,s'      " and set it to default

    return {
                \ 'mapmode': a:mapmode,
                \ 'oldpos':  getpos('.'),
                \ 'minline': line('w0'),
                \ 'maxline': line('w$'),
                \ 'withOldpos': function('s:contextWithOldpos'),
                \ }
endfunction

" save old visual selection to detect new selections and reselect on fail
function! s:initX()
    let context = s:init('x')

    let s:visualTarget = targets#target#fromVisualSelection(s:selection)

    " reselect, save mode and go back to normal mode
    normal! gv
    if mode() ==# 'V'
        let s:visualTarget.linewise = 1
        normal! V
    else
        normal! v
    endif

    " need to update oldpos here to make reselect work (see test8)
    " TODO: can we improve the flow here to avoid this double assignment?
    " TODO: also reselect only works if cursor is on end of selection, not on
    " start, fix that too
    let context.oldpos = getpos('.')

    let s:newSelection = s:isNewSelection()
    return context
endfunction

" clean up script variables after match
function! s:cleanUp()
    " reset remembered settings
    let &selection   = s:selection
    let &virtualedit = s:virtualedit
    let &whichwrap   = s:whichwrap
endfunction

function! s:findTarget(context, delimiter, which, modifier, count)
    let factories = s:getFactories(a:delimiter)
    if empty(factories)
        let errorTarget = targets#target#withError("failed to find delimiter")
        return [errorTarget, errorTarget]
    endif

    let view = winsaveview()
    let rawTarget = s:findRawTarget(a:context, factories, a:which, a:count)
    let target = s:modifyTarget(rawTarget, a:modifier)
    call winrestview(view)
    return [target, rawTarget]
endfunction

function! s:findRawTarget(context, factories, which, count)
    let context = a:context

    " TODO: clean these up
    if a:which ==# 'c'
        if a:count == 1 && s:newSelection " seek
            let gen = s:newMultiGen(context)
            call gen.add(a:factories, 'C', 'N', 'L')

        else " don't seek
            if !s:newSelection
                call s:lastRawTarget.cursorE() " start from last raw end
                let context = a:context.withOldpos(getpos('.'))
            endif
            let gen = s:newMultiGen(context)
            call gen.add(a:factories, 'C')
        endif

    elseif a:which ==# 'n'
        if !s:newSelection
            call s:lastRawTarget.cursorS() " start from last raw start
            let context = a:context.withOldpos(getpos('.'))
        endif
        let gen = s:newMultiGen(context)
        call gen.add(a:factories, 'N')

    elseif a:which ==# 'l'
        if !s:newSelection
            call s:lastRawTarget.cursorE() " start from last raw end
            let context = a:context.withOldpos(getpos('.'))
        endif
        let gen = s:newMultiGen(context)
        call gen.add(a:factories, 'L')

    else
        return targets#target#withError('findRawTarget which')
    endif

    return gen.nextN(a:count)
endfunction

function! s:modifyTarget(target, modifier)
    if a:target.state().isInvalid()
        return targets#target#withError('modifyTarget invalid: ' . a:target.error)
    endif
    let target = a:target.copy()
    let kind = a:target.gen.kind

    if kind ==# 'p'
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

    elseif kind ==# 'q'
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

    elseif kind ==# 's'
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

    elseif kind ==# 't'
        if a:modifier ==# 'i'
            return s:drop(s:innert(target))
        elseif a:modifier ==# 'a'
            return target
        elseif a:modifier ==# 'I'
            return s:shrink(s:innert(target))
        elseif a:modifier ==# 'A'
            return s:expand(target)
        else
            return targets#target#withError('modifyTarget t')
        endif

    elseif kind ==# 'a'
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

function! s:getFactories(trigger)
    " create cache
    if !exists('s:factoriesCache')
        let s:factoriesCache = {}
    endif

    " check cache
    if has_key(s:factoriesCache, a:trigger)
        return s:factoriesCache[a:trigger]
    endif

    let factories = s:getNewFactories(a:trigger)
    " write to cache (even if no factories were returned)
    let s:factoriesCache[a:trigger] = factories
    return factories
endfunction

" returns list of [kind, argsForKind], potentially empty
function! s:getNewFactories(trigger)
    let multi = get(g:targets_multis, a:trigger, 0)
    if type(multi) == type({})
        return s:getMultiFactories(multi)
    endif

    " check more specific ones first for #145
    if a:trigger ==# g:targets_tagTrigger " TODO: does this work with custom trigger?
        return [s:newFactoryT()]
    endif

    if a:trigger ==# g:targets_argTrigger " TODO: does this work with custom trigger?
        return [s:newFactoryA()]
    endif

    for pair in split(g:targets_pairs)
        for trigger in split(pair, '\zs')
            if trigger ==# a:trigger
                return [s:newFactoryP(pair[0], pair[1])]
            endif
        endfor
    endfor

    for quote in split(g:targets_quotes)
        for trigger in split(quote, '\zs')
            if trigger ==# a:trigger
                return [s:newFactoryQ(quote[0])]
            endif
        endfor
    endfor

    for separator in split(g:targets_separators)
        for trigger in split(separator, '\zs')
            if trigger ==# a:trigger
                return [s:newFactoryS(separator[0])]
            endif
        endfor
    endfor

    return []
endfunction

function! s:getMultiFactories(multi)
    let factories = []
    for kind in keys(s:registry)
        for args in get(a:multi, kind, [])
            call add(factories, call(s:registry[kind], args))
        endfor
    endfor
    return factories
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
    if !s:lastTarget.equal(s:visualTarget)
        return 1
    endif

    return 0
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
    let range = a:target.range(a:context)[0]
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

    " TODO: this wouldn't work with custom iaIAnl, right?
    " maybe the trigger args should just always include what's typed
    " and then we translate in here with the cache, potentially without splitting
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
function! s:quoteDir(delimiter)
    let line = getline('.')
    let col = col('.')

    " cut line in left of, on and right of cursor
    let left = col > 1 ? line[:col-2] : ""
    let cursor = line[col-1]
    let right = line[col :]

    " how many delitimers left, on and right of cursor
    let lc = s:count(a:delimiter, left)
    let cc = s:count(a:delimiter, cursor)
    let rc = s:count(a:delimiter, right)

    " truncate counts
    let lc = lc == 0 ? 0 : lc % 2 == 0 ? 2 : 1
    let rc = rc == 0 ? 0 : rc % 2 == 0 ? 2 : 1

    let key = lc . cc . rc
    let defaultValues = ['', 0, 0, 0, 'bad key: ' . key]
    let [dir, rate, skipL, skipR, error] = get(s:quoteDirs, key, defaultValues)
    return [dir, rate, skipL, skipR, error]
endfunction

" match selectors
" ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯

" select pair of delimiters around cursor (multi line, no seeking)
" select to the right if cursor is on a delimiter
" cursor  │   ....
" line    │ ' ' b ' '
" matcher │   └───┘
function! s:select(opening, closing, direction, gen)
    if a:direction ==# ''
        return targets#target#withError('select without direction')
    elseif a:direction ==# '>'
        let [sl, sc] = searchpos(a:opening, 'bcW') " search left for opening
        let [el, ec] = searchpos(a:closing, 'W')   " then right for closing
        return targets#target#fromValues(sl, sc, el, ec, a:gen)
    else
        let [el, ec] = searchpos(a:closing, 'cW') " search right for closing
        let [sl, sc] = searchpos(a:opening, 'bW') " then left for opening
        return targets#target#fromValues(sl, sc, el, ec, a:gen)
    endif
endfunction

" select a pair around the cursor
" args (count, trigger)
function! s:selectp(count, trigger, gen)
    " try to select pair
    silent! execute 'keepjumps normal! v' . a:count . 'a' . a:trigger
    let [el, ec] = getpos('.')[1:2]
    silent! normal! o
    let [sl, sc] = getpos('.')[1:2]
    silent! normal! v

    if sc == ec && sl == el
        return targets#target#withError('selectp')
    endif

    return targets#target#fromValues(sl, sc, el, ec, a:gen)
endfunction

" select an argument around the cursor
" parameter direction decides where to select when invoked on a separator:
"   '>' select to the right (default)
"   '<' select to the left (used when selecting or skipping to the left)
"   '^' select up (surrounding argument, used for growing)
function! s:selecta(direction, gen)
    let oldpos = getpos('.')

    let [opening, closing] = [s:argOpening, s:argClosing]
    if a:direction ==# '^'
        if s:getchar() =~# closing
            let [sl, sc, el, ec, err] = s:findArg(a:direction, 'cW', 'bW', 'bW', opening, closing)
        else
            let [sl, sc, el, ec, err] = s:findArg(a:direction, 'W', 'bcW', 'bW', opening, closing)
        endif
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

    return targets#target#fromValues(sl, sc, el, ec, a:gen)
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

" returns best target (and its index) according to range score and distance to cursor
function! s:bestTarget(targets, context, message)
    let [bestScore, minLines, minChars] = [0, 1/0, 1/0] " 1/0 = maxint

    let cnt = len(a:targets)
    for idx in range(cnt)
        let target = a:targets[idx]
        let [range, lines, chars] = target.range(a:context)
        let score = get(s:rangeScores, range)

        " if target.state().isValid()
        "     echom target.string()
        "     echom 'score ' . score . ' lines ' . lines . ' chars ' . chars
        " endif

        if (score > bestScore) ||
                    \ (score == bestScore && lines < minLines) ||
                    \ (score == bestScore && lines == minLines && chars < minChars)
            let [bestScore, minLines, minChars, best, bestIdx] = [score, lines, chars, target, idx]
        endif
    endfor

    if exists('best')
        " echom 'best ' . best.string()
        " echom 'score ' . bestScore . ' lines ' . minLines . ' chars ' . minChars
        return [best, bestIdx]
    endif

    return [targets#target#withError(a:message), -1]
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

" returns the character under the cursor
function! s:getchar()
    return getline('.')[col('.')-1]
endfunction

" search for pattern using flags and a count, optional stopline
" args (cnt, pattern, flags, stopline=0)
function! s:search(...)
    let cnt      =            a:1 " required TODO: make optional with default 1?
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

" TODO: move to new file and rename functions accordingly, make autoloaded?

" returns a factory to create generators
" TODO: inject context instead of oldpos?
" TODO: remove kind later when we have modifyTarget functions per factory
function! s:newFactory(kind, trigger, name, args)
    return {
                \ 'kind':    a:kind,
                \ 'trigger': a:trigger,
                \ 'name':    a:name,
                \ 'args':    a:args,
                \
                \ 'new': function('s:factoryNew'),
                \ }
endfunction

" returns a target generator
function! s:factoryNew(oldpos, which) dict
    return {
                \ 'kind':    self.kind,
                \ 'trigger': self.trigger,
                \ 'name':    self.name . a:which,
                \ 'args':    self.args,
                \ 'oldpos':  a:oldpos,
                \
                \ 'next':   function('s:genNext'),
                \ 'nexti':  function('s:genNext' . self.name . a:which),
                \ 'nextN':  function('s:genNextN'),
                \ 'target': function('s:genTarget')
                \ }
endfunction

function! s:genNext(first) dict
    call setpos('.', self.oldpos)
    let self.currentTarget = self.nexti(a:first) " call internal function
    let self.oldpos = getpos('.')
    return self.currentTarget
endfunction

function! s:genTarget() dict
    return get(self, 'currentTarget', targets#target#withError('no target'))
endfunction

function! s:genNextN(n) dict
    for i in range(1, a:n)
        let target = self.next(i == 1)
        if target.state().isInvalid()
            return target
        endif
    endfor

    return target
endfunction

" TODO: use some templating here to avoid repetition?

" pairs

function! s:newFactoryP(opening, closing)
    let args = {
                \ 'opening': s:modifyDelimiter('p', a:opening),
                \ 'closing': s:modifyDelimiter('p', a:closing),
                \ 'trigger': s:modifyDelimiter('p', a:closing)
                \ }
    return s:newFactory('p', a:closing, 'P', args)
endfunction

" tag factory uses pair functions as well for now
" special args must not be modified/escaped
" TODO: tag growing doesn't work vatat, also v2at
function! s:newFactoryT()
    let args = {
                \ 'opening': '<\a',
                \ 'closing': '</\a\zs',
                \ 'trigger': 't'
                \ }
    return s:newFactory('t', 't', 'P', args)
endfunction

function! s:genNextPC(first) dict
    if a:first
        let cnt = 1
    else
        let cnt = 2
    endif

    let target = s:selectp(cnt, self.args.trigger, self)
    call target.cursorE() " keep going from right end
    return target
endfunction

function! s:genNextPN(first) dict
    " echom 'PN ' . string(getpos('.')) . ' ' . self.trigger
    if s:search(1, self.args.opening, 'W') > 0
        return targets#target#withError('no target')
    endif

    let oldpos = getpos('.')
    let target = s:selectp(1, self.args.trigger, self)
    call setpos('.', oldpos)
    " echom 'ret ' . target.string()
    return target
endfunction

function! s:genNextPL(first) dict
    if s:search(1, self.args.closing, 'bW') > 0
        return targets#target#withError('no target')
    endif

    let oldpos = getpos('.')
    let target = s:selectp(1, self.args.trigger, self)
    call setpos('.', oldpos)
    return target
endfunction

" quotes

function! s:newFactoryQ(delimiter)
    let args = {'delimiter': s:modifyDelimiter('q', a:delimiter)}
    return s:newFactory('q', a:delimiter, 'Q', args)
endfunction

function! s:genNextQC(first) dict
    if !a:first
        return targets#target#withError('only one current quote')
    endif

    let dir = s:quoteDir(self.args.delimiter)[0]
    let self.currentTarget = s:select(self.args.delimiter, self.args.delimiter, dir, self)
    return self.currentTarget
endfunction

function! s:genNextQN(first) dict
    if !exists('self.rate')
        " do outside somehow? if so remember to reset pos before
        " TODO: yes do on init somehow. that way we don't need to do it three
        " times for seekipng
        let [_, self.rate, _, skipR, _] = s:quoteDir(self.args.delimiter)
        let cnt = self.rate - skipR " skip initially once
        " echom 'skip'
    else
        let cnt = self.rate " then go by rate
        " echom 'no skip'
    endif

    if s:search(cnt, self.args.delimiter, 'W') > 0
        return targets#target#withError('QN')
    endif

    let target = s:select(self.args.delimiter, self.args.delimiter, '>', self)
    call target.cursorS() " keep going from left end TODO: is this call needed?
    return target
endfunction

function! s:genNextQL(first) dict
    if !exists('self.rate')
        let [_, self.rate, skipL, _, _] = s:quoteDir(self.args.delimiter)
        let cnt = self.rate - skipL " skip initially once
        " echom 'skip'
    else
        let cnt = self.rate " then go by rate
        " echom 'no skip'
    endif

    if s:search(cnt, self.args.delimiter, 'bW') > 0
        return targets#target#withError('QL')
    endif

    let target = s:select(self.args.delimiter, self.args.delimiter, '<', self)
    call target.cursorE() " keep going from right end TODO: is this call needed?
    return target
endfunction

" separators

function! s:newFactoryS(delimiter)
    let args = {'delimiter': s:modifyDelimiter('s', a:delimiter)}
    return s:newFactory('s', a:delimiter, 'S', args)
endfunction

function! s:genNextSC(first) dict
    if !a:first
        return targets#target#withError('only one current separator')
    endif

    return s:select(self.args.delimiter, self.args.delimiter, '>', self)
endfunction

function! s:genNextSN(first) dict
    if s:search(1, self.args.delimiter, 'W') > 0
        return targets#target#withError('no target')
    endif

    let oldpos = getpos('.')
    let target = s:select(self.args.delimiter, self.args.delimiter, '>', self)
    call setpos('.', oldpos)
    return target
endfunction

function! s:genNextSL(first) dict
    if a:first
        let flags = 'cbW' " allow separator under cursor on first iteration
    else
        let flags = 'bW'
    endif

    if s:search(1, self.args.delimiter, flags) > 0
        return targets#target#withError('no target')
    endif

    let oldpos = getpos('.')
    let target = s:select(self.args.delimiter, self.args.delimiter, '<', self)
    call setpos('.', oldpos)
    return target
endfunction

" arguments

function! s:newFactoryA()
    return s:newFactory('a', 'a', 'A', {})
endfunction

function! s:genNextAC(first) dict
    if a:first
        let target = s:selecta('^', self)
    else
        if s:findArgBoundary('cW', 'cW', s:argOpening, s:argClosing, s:argOuter, s:none, 1)[2] > 0
            return targets#target#withError('AC 1')
        endif
        silent! execute "normal! 1 "
        let target = s:selecta('<', self)
    endif

    call target.cursorE() " keep going from right end
    return target
endfunction

function! s:genNextAN(first) dict
    " search for opening or separator, try to select argument from there
    " if that fails, keep searching for opening until an argument can be
    " selected
    let pattern = s:argOpeningS
    while 1
        if s:search(1, pattern, 'W') > 0
            return targets#target#withError('no target')
        endif

        let oldpos = getpos('.')
        let target = s:selecta('>', self)
        call setpos('.', oldpos)

        if target.state().isValid()
            return target
        endif

        let pattern = s:argOpening
    endwhile
endfunction

function! s:genNextAL(first) dict
    " search for closing or separator, try to select argument from there
    " if that fails, keep searching for closing until an argument can be
    " selected
    let pattern = s:argClosingS
    while 1
        if s:search(1, pattern, 'bW') > 0
            return targets#target#withError('no target')
        endif

        let oldpos = getpos('.')
        let target = s:selecta('<', self)
        call setpos('.', oldpos)

        if target.state().isValid()
            return target
        endif

        let pattern = s:argClosing
    endwhile
endfunction

function! s:newMultiGen(context)
    return {
                \ 'gens':    [],
                \ 'context': a:context,
                \
                \ 'add':    function('s:multiGenAdd'),
                \ 'next':   function('s:multiGenNext'),
                \ 'nextN':  function('s:genNextN'),
                \ 'target': function('s:genTarget')
                \ }
endfunction

function! s:multiGenAdd(factories, ...) dict
    let whichs = a:000
    for factory in a:factories
        for which in whichs
            call add(self.gens, factory.new(self.context.oldpos, which))
        endfor
    endfor
endfunction

function! s:multiGenNext(first) dict
    if a:first
        for gen in self.gens
            let first = s:newSelection || s:lastRawTarget.gen.trigger != gen.trigger
            call gen.next(first)
        endfor
    else
        call self.currentTarget.gen.next(0) " fill up where we used the last target from
    endif

    let targets = []
    for gen in self.gens
        call add(targets, gen.target())
    endfor

    while 1
        let [target, idx] = s:bestTarget(targets, self.context, 'multigen')
        if target.state().isInvalid() " best is invalid -> done
            let self.currentTarget = target
            return self.currentTarget
        endif

        " TODO: can we merge current target and last raw target to avoid this
        " sort of duplication?
        if exists('self.currentTarget')
            if self.currentTarget.equal(target)
                " current target is the same as last one, skip it and try the next one
                let targets[idx] = target.gen.next(0)
                continue
            endif
        elseif !s:newSelection && s:lastRawTarget.equal(target)
            " current target is the same as continued one, skip it and try the next one
            " NOTE: this can happen if a multi contains two generators which
            " may create the same target. in that case growing might break
            " without this check
            let targets[idx] = target.gen.next(0)
            continue
        endif

        let self.currentTarget = target
        return self.currentTarget
    endwhile
endfunction

" TODO: move to separate file?
function! s:contextWithOldpos(oldpos) dict
    let context = deepcopy(self)
    let context.oldpos = a:oldpos
    return context
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

call s:setup()

" reset cpoptions
let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
