" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license

if exists("g:loaded_targets") || &cp || v:version < 700
    finish
endif
let g:loaded_targets = '0.4.6' " version number
let s:save_cpoptions = &cpoptions
set cpo&vim

function! s:addMapping1(mapType, mapping, aiAI)
    if a:aiAI !=# ' '
        silent! execute a:mapType . 'noremap <silent> <unique>' . a:aiAI . a:mapping
    endif
endfunction

function! s:addMapping2(mapType, mapping, aiAI, nl)
    if a:aiAI !=# ' ' && a:nl !=# ' '
        silent! execute a:mapType . 'noremap <silent> <unique>' . a:aiAI . a:nl . a:mapping
    endif
endfunction

" pair text objects (multi line objects with single line seek)
" cursor  │                        .........
" line    │ a ( bbbbbb ) ( ccccc ) ( ddddd ) ( eeeee ) ( ffffff ) g
" command │   ││└2Il)┘│││││└Il)┘│││││└─I)┘│││││└In)┘│││││└2In)┘│││
"         │   │└─2il)─┘│││└─il)─┘│││└──i)─┘│││└─in)─┘│││└─2in)─┘││
"         │   ├──2al)──┘│├──al)──┘│├───a)──┘│├──an)──┘│├──2an)──┘│
"         │   └──2Al)───┘└──Al)───┘└───A)───┘└──An)───┘└──2An)───┘
" cursor  │                          .........
" line    │ a ( b ( cccccc ) d ) ( e ( fffff ) g ) ( h ( iiiiii ) j ) k
" command │   │││ ││└2Il)┘││││││││││ ││└─I)┘││││││││││ ││└2In)┘│││││││
"         │   │││ │└─2il)─┘│││││││││ │└──i)─┘│││││││││ │└─2in)─┘││││││
"         │   │││ ├──2al)──┘││││││││ ├───a)──┘││││││││ ├──2an)──┘│││││
"         │   │││ └──2Al)───┘│││││││ └───A)───┘│││││││ └──2An)───┘││││
"         │   ││└─────Il)────┘│││││└────2I)────┘│││││└─────In)────┘│││
"         │   │└──────il)─────┘│││└─────2i)─────┘│││└──────in)─────┘││
"         │   ├───────al)──────┘│├──────2a)──────┘│├───────an)──────┘│
"         │   └───────Al)───────┘└──────2A)───────┘└───────An)───────┘
function! s:createPairTextObjects(mapType)
    for trigger in split(g:targets_pairs, '\zs')
        if trigger ==# ' '
            continue
        endif
        let triggerMap = trigger . " :<C-U>call targets#" . a:mapType . "('" . trigger
        call s:addMapping1(a:mapType, triggerMap . "ci', v:count1)<CR>", s:i)
        call s:addMapping1(a:mapType, triggerMap . "ca', v:count1)<CR>", s:a)
        call s:addMapping1(a:mapType, triggerMap . "cI', v:count1)<CR>", s:I)
        call s:addMapping1(a:mapType, triggerMap . "cA', v:count1)<CR>", s:A)
        call s:addMapping2(a:mapType, triggerMap . "ni', v:count1)<CR>", s:i, s:n)
        call s:addMapping2(a:mapType, triggerMap . "na', v:count1)<CR>", s:a, s:n)
        call s:addMapping2(a:mapType, triggerMap . "nI', v:count1)<CR>", s:I, s:n)
        call s:addMapping2(a:mapType, triggerMap . "nA', v:count1)<CR>", s:A, s:n)
        call s:addMapping2(a:mapType, triggerMap . "li', v:count1)<CR>", s:i, s:l)
        call s:addMapping2(a:mapType, triggerMap . "la', v:count1)<CR>", s:a, s:l)
        call s:addMapping2(a:mapType, triggerMap . "lI', v:count1)<CR>", s:I, s:l)
        call s:addMapping2(a:mapType, triggerMap . "lA', v:count1)<CR>", s:A, s:l)
    endfor
endfunction

" tag text objects work on tags (similar to pair text objects)
function! s:createTagTextObjects(mapType)
    let trigger = g:targets_tagTrigger
    let triggerMap = trigger . " :<C-U>call targets#" . a:mapType . "('" . trigger
    call s:addMapping1(a:mapType, triggerMap . "ci', v:count1)<CR>", s:i)
    call s:addMapping1(a:mapType, triggerMap . "ca', v:count1)<CR>", s:a)
    call s:addMapping1(a:mapType, triggerMap . "cI', v:count1)<CR>", s:I)
    call s:addMapping1(a:mapType, triggerMap . "cA', v:count1)<CR>", s:A)
    call s:addMapping2(a:mapType, triggerMap . "ni', v:count1)<CR>", s:i, s:n)
    call s:addMapping2(a:mapType, triggerMap . "na', v:count1)<CR>", s:a, s:n)
    call s:addMapping2(a:mapType, triggerMap . "nI', v:count1)<CR>", s:I, s:n)
    call s:addMapping2(a:mapType, triggerMap . "nA', v:count1)<CR>", s:A, s:n)
    call s:addMapping2(a:mapType, triggerMap . "li', v:count1)<CR>", s:i, s:l)
    call s:addMapping2(a:mapType, triggerMap . "la', v:count1)<CR>", s:a, s:l)
    call s:addMapping2(a:mapType, triggerMap . "lI', v:count1)<CR>", s:I, s:l)
    call s:addMapping2(a:mapType, triggerMap . "lA', v:count1)<CR>", s:A, s:l)
endfunction

" quote text objects expand into quote (by counting quote signs)
" `aN'` is a shortcut for `2an'` to jump from within one quote into the
" next one, instead of the quote in between
" cursor  │                   ........
" line    │ a ' bbbbb ' ccccc ' dddd ' eeeee ' fffff ' g
" command │   ││└IL'┘│││└Il'┘│││└I'┘│││└In'┘│││└IN'┘│││
"         │   │└─iL'─┘│├─il'─┘│├─i'─┘│├─in'─┘│├─iN'─┘││
"         │   ├──aL'──┤│      ├┼─a'──┤│      ├┼─aN'──┘│
"         │   └──AL'──┼┘      ├┼─A'──┼┘      ├┼─AN'───┘
"         │           ├──al'──┘│     ├──an'──┘│
"         │           └──Al'───┘     └──An'───┘
" cursor  │ ..........      │      ......      │      ..........
" line    │ a ' bbbb ' c '' │ ' a ' bbbb ' c ' │ '' b ' cccc ' d
" command │   ││└I'┘│││     │     ││└I'┘│││    │      ││└I'┘│││
"         │   │└─i'─┘││     │     │└─i'─┘││    │      │└─i'─┘││
"         │   ├──a'──┘│     │     ├──a'──┘│    │      ├──a'──┘│
"         │   └──A'───┘     │     └──A'───┘    │      └──A'───┘
function! s:createQuoteTextObjects(mapType)
    " quote text objects
    for trigger in split(g:targets_quotes, '\zs')
        if trigger ==# " "
            continue
        elseif trigger ==# "'"
            let triggerMap = "' :<C-U>call targets#" . a:mapType . "('''"
        else
            let triggerMap = trigger . " :<C-U>call targets#" . a:mapType . "('" . trigger
        endif
        call s:addMapping1(a:mapType, triggerMap . "ci', v:count1)<CR>", s:i)
        call s:addMapping1(a:mapType, triggerMap . "ca', v:count1)<CR>", s:a)
        call s:addMapping1(a:mapType, triggerMap . "cI', v:count1)<CR>", s:I)
        call s:addMapping1(a:mapType, triggerMap . "cA', v:count1)<CR>", s:A)
        call s:addMapping2(a:mapType, triggerMap . "ni', v:count1)<CR>", s:i, s:n)
        call s:addMapping2(a:mapType, triggerMap . "na', v:count1)<CR>", s:a, s:n)
        call s:addMapping2(a:mapType, triggerMap . "nI', v:count1)<CR>", s:I, s:n)
        call s:addMapping2(a:mapType, triggerMap . "nA', v:count1)<CR>", s:A, s:n)
        call s:addMapping2(a:mapType, triggerMap . "li', v:count1)<CR>", s:i, s:l)
        call s:addMapping2(a:mapType, triggerMap . "la', v:count1)<CR>", s:a, s:l)
        call s:addMapping2(a:mapType, triggerMap . "lI', v:count1)<CR>", s:I, s:l)
        call s:addMapping2(a:mapType, triggerMap . "lA', v:count1)<CR>", s:A, s:l)
    endfor
endfunction

" separator text objects expand to the right
" cursor  │              .............
" line    │ a ' bbbbbbb ' c ' dddddd ' e ' fffffff ' g ~
" command │   ││└ Il' ┘│││  ││└ I' ┘│││  ││└ In' ┘│││
"         │   │└─ il' ─┘││  │└─ i' ─┘││  │└─ in' ─┘││
"         │   ├── al' ──┘│  ├── a' ──┘│  ├── an' ──┘│
"         │   └── Al' ───┘  └── A' ───┘  └── An' ───┘
" cursor  │ .........        │       ..........
" line    │ a , bbbb , c , d │ a , b , cccc , d
" command │   ││└I,┘│ │      │       ││└I,┘│ │
"         │   │└─i,─┤ │      │       │└─i,─┤ │
"         │   ├──a,─┘ │      │       ├──a,─┘ │
"         │   └──A,───┘      │       └──A,───┘
function! s:createSeparatorTextObjects(mapType)
    " separator text objects
    for trigger in split(g:targets_separators, '\zs')
        if trigger ==# ' '
            continue
        elseif trigger ==# '|'
            let trigger = '\|'
        endif
        let triggerMap = trigger . " :<C-U>call targets#" . a:mapType . "('" . trigger
        call s:addMapping1(a:mapType, triggerMap . "ci', v:count1)<CR>", s:i)
        call s:addMapping1(a:mapType, triggerMap . "ca', v:count1)<CR>", s:a)
        call s:addMapping1(a:mapType, triggerMap . "cI', v:count1)<CR>", s:I)
        call s:addMapping1(a:mapType, triggerMap . "cA', v:count1)<CR>", s:A)
        call s:addMapping2(a:mapType, triggerMap . "ni', v:count1)<CR>", s:i, s:n)
        call s:addMapping2(a:mapType, triggerMap . "na', v:count1)<CR>", s:a, s:n)
        call s:addMapping2(a:mapType, triggerMap . "nI', v:count1)<CR>", s:I, s:n)
        call s:addMapping2(a:mapType, triggerMap . "nA', v:count1)<CR>", s:A, s:n)
        call s:addMapping2(a:mapType, triggerMap . "li', v:count1)<CR>", s:i, s:l)
        call s:addMapping2(a:mapType, triggerMap . "la', v:count1)<CR>", s:a, s:l)
        call s:addMapping2(a:mapType, triggerMap . "lI', v:count1)<CR>", s:I, s:l)
        call s:addMapping2(a:mapType, triggerMap . "lA', v:count1)<CR>", s:A, s:l)
    endfor
endfunction

" argument text objects expand to the right
" cursor  │                          .........
" line    │ a ( bbbbbb , ccccccc , d ( eeeeee , fffffff ) , gggggg ) h
" command │   ││├2Ila┘│││└─Ila─┘││││ ││├─Ia─┘│││└─Ina─┘│││││└2Ina┘│ │
"         │   │└┼2ila─┘│├──ila──┤│││ │└┼─ia──┘│├──ina──┤│││├─2ina─┤ │
"         │   │ └2ala──┼┤       ││││ │ └─aa───┼┤       │││├┼─2ana─┘ │
"         │   └──2Ala──┼┘       ││││ └───Aa───┼┘       │││└┼─2Ana───┘
"         │            ├───ala──┘│││          ├───ana──┘││ │
"         │            └───Ala───┼┤│          └───Ana───┼┤ │
"         │                      ││└─────2Ia────────────┘│ │
"         │                      │└──────2ia─────────────┤ │
"         │                      ├───────2aa─────────────┘ │
"         │                      └───────2Aa───────────────┘
function! s:createArgTextObjects(mapType)
    let trigger = g:targets_argTrigger
    let triggerMap = trigger . " :<C-U>call targets#" . a:mapType . "('" . trigger
    call s:addMapping1(a:mapType, triggerMap . "ci', v:count1)<CR>", s:i)
    call s:addMapping1(a:mapType, triggerMap . "ca', v:count1)<CR>", s:a)
    call s:addMapping1(a:mapType, triggerMap . "cI', v:count1)<CR>", s:I)
    call s:addMapping1(a:mapType, triggerMap . "cA', v:count1)<CR>", s:A)
    call s:addMapping2(a:mapType, triggerMap . "ni', v:count1)<CR>", s:i, s:n)
    call s:addMapping2(a:mapType, triggerMap . "na', v:count1)<CR>", s:a, s:n)
    call s:addMapping2(a:mapType, triggerMap . "nI', v:count1)<CR>", s:I, s:n)
    call s:addMapping2(a:mapType, triggerMap . "nA', v:count1)<CR>", s:A, s:n)
    call s:addMapping2(a:mapType, triggerMap . "li', v:count1)<CR>", s:i, s:l)
    call s:addMapping2(a:mapType, triggerMap . "la', v:count1)<CR>", s:a, s:l)
    call s:addMapping2(a:mapType, triggerMap . "lI', v:count1)<CR>", s:I, s:l)
    call s:addMapping2(a:mapType, triggerMap . "lA', v:count1)<CR>", s:A, s:l)
endfunction

function! s:addMappings()
    if v:version >= 704 || (v:version == 703 && has('patch338'))
        " if possible, create only a few expression mappings to speed up loading times
        silent! execute 'omap <expr> <unique> ' . s:i . " targets#e('i', '" . s:i . "')"
        silent! execute 'omap <expr> <unique> ' . s:a . " targets#e('a', '" . s:a . "')"
        silent! execute 'omap <expr> <unique> ' . s:I . " targets#e('I', '" . s:I . "')"
        silent! execute 'omap <expr> <unique> ' . s:A . " targets#e('A', '" . s:A . "')"

        silent! execute 'xmap <expr> <unique> ' . s:i . " targets#e('i', '" . s:i . "')"
        silent! execute 'xmap <expr> <unique> ' . s:a . " targets#e('a', '" . s:a . "')"
        silent! execute 'xmap <expr> <unique> ' . s:I . " targets#e('I', '" . s:I . "')"
        silent! execute 'xmap <expr> <unique> ' . s:A . " targets#e('A', '" . s:A . "')"

        " #209: The above mappings don't use <silent> for better visual
        " feedback on `!ip` (when we pass back control to Vim). To be silent
        " when calling internal targest functions, we use this special mapping
        " which does use <silent>. It should not lead to conflicts because (
        " is not a valid register.
        onoremap <silent> @(targets) :<C-u>call targets#do()<CR>
        xnoremap <silent> @(targets) :<C-u>call targets#do()<CR>

    else
        " otherwise create individual mappings #117

        " more specific ones first for #145
        call s:createTagTextObjects('o')
        call s:createArgTextObjects('o')
        call s:createPairTextObjects('o')
        call s:createQuoteTextObjects('o')
        call s:createSeparatorTextObjects('o')

        call s:createTagTextObjects('x')
        call s:createArgTextObjects('x')
        call s:createPairTextObjects('x')
        call s:createQuoteTextObjects('x')
        call s:createSeparatorTextObjects('x')
    endif
endfunction

function! s:loadSettings()
    let g:targets_nl         = get(g:, 'targets_nl', get(g:, 'targets_nlNL', 'nl')[0:1]) " legacy fallback
    let g:targets_aiAI       = get(g:, 'targets_aiAI', 'aiAI')
    let g:targets_pairs      = get(g:, 'targets_pairs', '()b {}B [] <>')
    let g:targets_quotes     = get(g:, 'targets_quotes', '" '' `')
    let g:targets_separators = get(g:, 'targets_separators', ', . ; : + - = ~ _ * # / \ | & $')
    let g:targets_tagTrigger = get(g:, 'targets_tagTrigger', 't')
    let g:targets_argTrigger = get(g:, 'targets_argTrigger', 'a')

    let [s:a, s:i, s:A, s:I] = split(g:targets_aiAI, '\zs')
    let [s:n, s:l] = split(g:targets_nl, '\zs')
endfunction

call s:loadSettings()
call s:addMappings()

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
