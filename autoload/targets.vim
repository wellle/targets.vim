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
                \ 'pairs':      function('targets#sources#pairs#new'),
                \ 'tags':       function('targets#sources#tags#new'),
                \ 'quotes':     function('targets#sources#quotes#new'),
                \ 'separators': function('targets#sources#separators#new'),
                \ 'arguments':  function('targets#sources#arguments#new'),
                \ }

    let g:targets_argOpening   = get(g:, 'targets_argOpening', '[([]')
    let g:targets_argClosing   = get(g:, 'targets_argClosing', '[])]')
    let g:targets_argSeparator = get(g:, 'targets_argSeparator', ',')

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
    let g:targets_quoteDirs = get(g:, 'targets_quoteDirs', {
                \ 'r1n': ['001', '201', '100', '102'],
                \ 'r1l': ['010', '012', '111', '210', '212'],
                \ 'r2n': ['101'],
                \ 'r2l': ['011', '211'],
                \ 'r2b': ['000'],
                \ 'l2r': ['110', '112'],
                \ 'n2b': ['002', '200', '202'],
                \ })

    let g:targets_multis = get(g:, 'targets_multis', {
                \ 'b': { 'pairs':  [['(', ')'], ['[', ']'], ['{', '}']], },
                \ 'q': { 'quotes': [["'"], ['"'], ['`']], },
                \ })

    let s:lastRawTarget = {}
endfunction

" a:count is unused here, but added for consistency with targets#x
function! targets#o(trigger, typed, count)
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
    call s:prepareRepeat(a:typed)
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

    let typed = a:original . chars
    if empty(s:getFactories(delimiter))
        return typed
    endif

    let delimiter = substitute(delimiter, "'", "''", "g")
    let typed = substitute(typed, "'", "''", "g")

    let s:call = prefix . delimiter . which . a:modifier . "', '" . typed . "', " . v:count1 . ")"
    " indirectly (but silently) call targets#do below
    return "@(targets)"
endfunction

" gets called via the @(targets) mapping from above
function! targets#do()
    exe s:call
endfunction

" 'x' is for visual (as in :xnoremap, not in select mode)
" a:typed is unused here, but added for consistency with targets#o
function! targets#x(trigger, typed, count)
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
    let s:selection = &selection  " remember 'selection' setting
    let &selection  = 'inclusive' " and set it to inclusive

    let s:virtualedit = &virtualedit " remember 'virtualedit' setting
    let &virtualedit  = ''           " and set it to default

    let s:whichwrap = &whichwrap " remember 'whichwrap' setting
    let &whichwrap  = 'b,s'      " and set it to default

    return {
                \ 'newSelection': 1,
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

    let visualTarget = targets#target#fromVisualSelection(s:selection)

    " reselect, save mode and go back to normal mode
    normal! gv
    if mode() ==# 'V'
        let visualTarget.linewise = 1
        normal! V
    else
        normal! v
    endif

    " need to update oldpos here to make reselect work (see test8)
    " TODO: can we improve the flow here to avoid this double assignment?
    " TODO: also reselect only works if cursor is on end of selection, not on
    " start, fix that too
    let context.oldpos = getpos('.')

    let context['newSelection'] = s:isNewSelection(visualTarget)
    let context['visualTarget'] = visualTarget
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
    let multigen = targets#multigen#new(context, s:lastRawTarget, s:rangeScores)

    if a:which ==# 'c'
        if a:count == 1 && a:context.newSelection " seek
            call multigen.add(a:factories, 'C', 'N', 'L')

        else " don't seek
            if !a:context.newSelection " start from last raw end
                let multigen.context = context.withOldpos(s:lastRawTarget.getposE())
            endif
            call multigen.add(a:factories, 'C')
        endif

    elseif a:which ==# 'n'
        if !a:context.newSelection " start from last raw start
            let multigen.context = context.withOldpos(s:lastRawTarget.getposS())
        endif
        call multigen.add(a:factories, 'N')

    elseif a:which ==# 'l'
        if !a:context.newSelection " start from last raw end
            let multigen.context = context.withOldpos(s:lastRawTarget.getposE())
        endif
        call multigen.add(a:factories, 'L')

    else
        return targets#target#withError('findRawTarget which')
    endif

    return multigen.nextN(a:count)
endfunction

function! s:modifyTarget(target, modifier)
    if a:target.state().isInvalid()
        return targets#target#withError('modifyTarget invalid: ' . a:target.error)
    endif

    let modFuncs = a:target.gen.factory.modFuncs
    if !has_key(modFuncs, a:modifier)
        return targets#target#withError('modifyTarget')
    endif

    let Funcs = modFuncs[a:modifier]
    if type(Funcs) == type(function('tr')) " single function
        return Funcs(a:target.copy())
    endif

    let target = a:target.copy()
    for Func in Funcs " list of functions
        let target = Func(target)
    endfor
    return target
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
        return [targets#sources#tags#new()]
    endif

    if a:trigger ==# g:targets_argTrigger " TODO: does this work with custom trigger?
        return [targets#sources#arguments#new(g:targets_argOpening, g:targets_argClosing, g:targets_argSeparator)]
    endif

    for pair in split(g:targets_pairs)
        for trigger in split(pair, '\zs')
            if trigger ==# a:trigger
                return [targets#sources#pairs#new(pair[0], pair[1])]
            endif
        endfor
    endfor

    for quote in split(g:targets_quotes)
        for trigger in split(quote, '\zs')
            if trigger ==# a:trigger
                return [targets#sources#quotes#new(quote[0])]
            endif
        endfor
    endfor

    for separator in split(g:targets_separators)
        for trigger in split(separator, '\zs')
            if trigger ==# a:trigger
                return [targets#sources#separators#new(separator[0])]
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

" return 0 if the selection changed since the last invocation. used for
" growing
function! s:isNewSelection(visualTarget)
    " no previous invocation or target
    if !exists('s:lastTarget')
        return 1
    endif

    " selection changed
    if !s:lastTarget.equal(a:visualTarget)
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

    return targets#util#fail(a:message)
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
        call s:selectRegion(a:context.visualTarget)
    endif
endfunction

" feed keys to reselect the last visual selection if called with mapmode x
function! s:triggerReselect(context)
    if a:context.mapmode ==# 'x'
        call feedkeys("gv", 'n')
    endif
endfunction

" set up repeat.vim for older Vim versions
function! s:prepareRepeat(typed)
    if v:version >= 704 " skip recent versions
        return
    endif

    if v:operator ==# 'y' && match(&cpoptions, 'y') ==# -1 " skip yank unless set up
        return
    endif

    let cmd = v:operator . a:typed
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

" TODO: move to separate file?
function! s:contextWithOldpos(oldpos) dict
    let context = deepcopy(self)
    let context.oldpos = a:oldpos
    return context
endfunction

call s:setup()

" reset cpoptions
let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
