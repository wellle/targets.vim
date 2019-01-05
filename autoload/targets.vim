" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license

" save cpoptions
let s:save_cpoptions = &cpoptions
set cpo&vim

" state which we need across invocations
let s:lastRawTarget = targets#target#withError('initial')
let s:lastTrigger   = "   "

" a:count is unused here, but added for consistency with targets#x
function! targets#o(trigger, typed, count)
    call s:init()
    let context = targets#context#new('o', a:trigger, 1, {})

    " reset last raw target to not avoid it in #o when it was set from #x
    let s:lastRawTarget = targets#target#withError('#o')

    let [target, rawTarget] = s:findTarget(context, v:count1)
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
function! targets#e(mapmode, modifier, original)
    " abort in block mode, to not break v_b_I and v_b_A
    if mode() !~# "[nvV]"
        return a:original
    endif

    let char1 = nr2char(getchar())
    let [trigger, which, chars] = [char1, 'c', char1]
    for i in range(2)
        if g:targets_nl[i] ==# trigger
            " trigger was which, get another char for trigger
            let char2 = nr2char(getchar())
            let [trigger, which, chars] = [char2, 'nl'[i], chars . char2]
            break
        endif
    endfor

    let typed = a:original . chars
    if empty(s:getFactories(trigger))
        return typed
    endif

    let trigger = substitute(trigger, "'", "''", "g")
    let typed = substitute(typed, "'", "''", "g")

    let s:call = "call targets#" . a:mapmode . "('" . trigger . which . a:modifier . "', '" . typed . "', " . v:count1 . ")"
    " indirectly (but silently) call targets#do below
    return "@(targets)"
endfunction

" gets called via the @(targets) mapping from above
function! targets#do()
    execute s:call
endfunction

" 'x' is for visual (as in :xnoremap, not in select mode)
" a:typed is unused here, but added for consistency with targets#o
function! targets#x(trigger, typed, count)
    let context = s:initX(a:trigger)

    let [target, rawTarget] = s:findTarget(context, a:count)
    if target.state().isInvalid()
        call s:abortMatch(context, '#x: ' . target.error)
        return s:cleanUp()
    endif
    if s:handleTarget(context, target, rawTarget) == 0
        let s:lastTrigger   = a:trigger " needed to decide wether to skip/grow
        let s:lastTarget    = target    " needed to decide whether selection has changed
        let s:lastRawTarget = rawTarget " needed to jump to start or end when growing/skipping
    endif
    call s:cleanUp()
endfunction

" initialize script local variables for the current matching
function! s:init()
    let s:selection = &selection  " remember 'selection' setting
    let &selection  = 'inclusive' " and set it to inclusive

    let s:virtualedit = &virtualedit " remember 'virtualedit' setting
    let &virtualedit  = ''           " and set it to default

    let s:whichwrap = &whichwrap " remember 'whichwrap' setting
    let &whichwrap  = 'b,s'      " and set it to default
endfunction

" save old visual selection to detect new selections and reselect on fail
function! s:initX(trigger)
    call s:init()

    let visualTarget = targets#target#fromVisualSelection(s:selection)

    let isNewSelection = s:isNewSelection(visualTarget)
    if isNewSelection
        let s:lastRawTarget = targets#target#withError('initial')
    endif

    return targets#context#new('x', a:trigger, isNewSelection, visualTarget)
endfunction

" clean up script variables after match
function! s:cleanUp()
    " reset remembered settings
    let &selection   = s:selection
    let &virtualedit = s:virtualedit
    let &whichwrap   = s:whichwrap
endfunction

function! s:findTarget(context, count)
    let delimiter = a:context.trigger[0]
    let modifier  = a:context.trigger[2]

    let factories = s:getFactories(delimiter)
    if empty(factories)
        let errorTarget = targets#target#withError("failed to find delimiter")
        return [errorTarget, errorTarget]
    endif

    let view = winsaveview()
    let rawTarget = s:findRawTarget(a:context, factories, a:count)
    let target = s:modifyTarget(rawTarget, modifier)
    call winrestview(view)
    return [target, rawTarget]
endfunction

function! s:findRawTarget(context, factories, count)
    let multigen = targets#multigen#new(a:context, s:lastRawTarget)
    let first = 1
    let [delimiter , which , modifier ] = split(a:context.trigger, '\zs')
    let [delimiterL, whichL, modifierL] = split(s:lastTrigger, '\zs')
    let sameDelimiter = delimiter ==# delimiterL
    let sameModifier  = modifier  ==# modifierL
    let similar = !a:context.newSelection && sameDelimiter

    " echom s:lastTrigger . ' ' a:context.trigger

    if which ==# 'c'
        if similar && sameModifier
            " grow if selection didn't change and the trigger is the same (or only which changed)
            let multigen = s:lastRawTarget.multigen      " continue with last gens
            let multigen.currentTarget = s:lastRawTarget " continue from here
            let multigen.lastRawTarget = s:lastRawTarget " skip current
            call filter(multigen.gens, 'v:val.which ==# "c"') " drop n/l gens

            if len(multigen.gens) > 0
                " echom 'same selection, same trigger, just grow'
                " if some gens are left we're good and can continue
                let first = 0
            else
                " echom 'same selection, same trigger, but no gen left, no seek'
                " if all gens have been filtered out, fall back to non seeking
                let multigen.context = a:context.withOldpos(s:lastRawTarget.getposS())
                call multigen.add(a:factories, 'c')
            endif

        elseif similar && !sameModifier && a:count == 1
            " echom 'different modifier only, reuse last target'
            " if the target is the same, but just the modifier is different, reuse
            " last raw target
            return s:lastRawTarget

        elseif !similar && a:count == 1
            " echom 'new selection or new delimiter, seek'
            " allow seeking if no count was given and the selection changed
            " or something different was typed
            call multigen.add(a:factories, 'c', 'n', 'l')

        else " don't seek
            " echom 'no grow, no seek'
            if !a:context.newSelection " start from last raw end
                let multigen.context = a:context.withOldpos(s:lastRawTarget.getposE())
            endif
            call multigen.add(a:factories, 'c')
        endif

    elseif which ==# 'n'
        if !a:context.newSelection " start from last raw start
            let multigen.context = a:context.withOldpos(s:lastRawTarget.getposS())
        endif
        call multigen.add(a:factories, 'n')

    elseif which ==# 'l'
        if !a:context.newSelection " start from last raw end
            let multigen.context = a:context.withOldpos(s:lastRawTarget.getposE())
        endif
        call multigen.add(a:factories, 'l')

    else
        return targets#target#withError('findRawTarget which')
    endif

    let target = multigen.nextN(a:count, first)
    let target.multigen = multigen
    return target
endfunction

function! s:modifyTarget(target, modifier)
    if a:target.state().isInvalid()
        return targets#target#withError('modifyTarget invalid: ' . a:target.error)
    endif
    " don't modify the original injected target (used as lastRawTarget)
    let target = a:target.copy()

    " use keep function by default
    let Funcs = get(target.gen.modFuncs, a:modifier, function('targets#modify#keep'))
    if type(Funcs) == type(function('tr')) " single function
        call Funcs(target, target.gen.args)
        return target
    endif

    for Func in Funcs " list of functions
        call Func(target, target.gen.args)
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

    let factories = targets#sources#newFactories(a:trigger)
    " write to cache (even if no factories were returned)
    let s:factoriesCache[a:trigger] = factories
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
    if !exists('s:rangeJumps')
        let s:rangeJumps = {}
        let ranges = split(get(g:, 'targets_jumpRanges', 'bb bB BB aa Aa AA'))
        for i in range(len(ranges))
            let s:rangeJumps[ranges[i]] = 1
        endfor
    endif
    return get(s:rangeJumps, a:target.range(a:context)[0])
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
        let cmd .= "\<C-R>.\<ESC>"
    endif

    silent! call repeat#set(cmd, v:count)
endfunction

" undo last operation if it created a new undo position
function! targets#undo(lastseq)
    if undotree().seq_cur > a:lastseq
        silent! execute 'normal! u'
    endif
endfunction

" reset cpoptions
let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
