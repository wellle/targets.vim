" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license
" Updated: 2014-11-01
" Version: 0.3.4

if exists("g:loaded_targets") || &cp || v:version < 700
    finish
endif
let g:loaded_targets = '0.3.4' " version number
let s:save_cpoptions = &cpoptions
set cpo&vim

function! s:addMapping1(mapping, aiAI)
    if a:aiAI !=# ' '
        silent! execute 'onoremap <silent> <unique>' . a:aiAI . a:mapping
    endif
endfunction

function! s:addMapping2(mapping, aiAI, nlNL)
    if a:aiAI !=# ' ' && a:nlNL !=# ' '
        silent! execute 'onoremap <silent> <unique>' . a:aiAI . a:nlNL . a:mapping
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
function! s:createPairTextObjects()
    for trigger in split(g:targets_pairs, '\zs')
        if trigger ==# ' '
            continue
        endif
        let triggerMap = trigger . " :<C-U>call targets#o('" . trigger
        call s:addMapping1(triggerMap . "ci')<CR>", s:i)
        call s:addMapping1(triggerMap . "ca')<CR>", s:a)
        call s:addMapping1(triggerMap . "cI')<CR>", s:I)
        call s:addMapping1(triggerMap . "cA')<CR>", s:A)
        call s:addMapping2(triggerMap . "ni')<CR>", s:i, s:n)
        call s:addMapping2(triggerMap . "na')<CR>", s:a, s:n)
        call s:addMapping2(triggerMap . "nI')<CR>", s:I, s:n)
        call s:addMapping2(triggerMap . "nA')<CR>", s:A, s:n)
        call s:addMapping2(triggerMap . "li')<CR>", s:i, s:l)
        call s:addMapping2(triggerMap . "la')<CR>", s:a, s:l)
        call s:addMapping2(triggerMap . "lI')<CR>", s:I, s:l)
        call s:addMapping2(triggerMap . "lA')<CR>", s:A, s:l)
    endfor
endfunction

" tag text objects work on tags (similar to pair text objects)
function! s:createTagTextObjects()
    let trigger = g:targets_tagTrigger
    let triggerMap = trigger . " :<C-U>call targets#o('" . trigger
    call s:addMapping1(triggerMap . "ci')<CR>", s:i)
    call s:addMapping1(triggerMap . "ca')<CR>", s:a)
    call s:addMapping1(triggerMap . "cI')<CR>", s:I)
    call s:addMapping1(triggerMap . "cA')<CR>", s:A)
    call s:addMapping2(triggerMap . "ni')<CR>", s:i, s:n)
    call s:addMapping2(triggerMap . "na')<CR>", s:a, s:n)
    call s:addMapping2(triggerMap . "nI')<CR>", s:I, s:n)
    call s:addMapping2(triggerMap . "nA')<CR>", s:A, s:n)
    call s:addMapping2(triggerMap . "li')<CR>", s:i, s:l)
    call s:addMapping2(triggerMap . "la')<CR>", s:a, s:l)
    call s:addMapping2(triggerMap . "lI')<CR>", s:I, s:l)
    call s:addMapping2(triggerMap . "lA')<CR>", s:A, s:l)
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
function! s:createQuoteTextObjects()
    " quote text objects
    for trigger in split(g:targets_quotes, '\zs')
        if trigger ==# " "
            continue
        elseif trigger ==# "'"
            let triggerMap = "' :<C-U>call targets#o('''"
        else
            let triggerMap = trigger . " :<C-U>call targets#o('" . trigger
        endif
        call s:addMapping1(triggerMap . "ci')<CR>", s:i)
        call s:addMapping1(triggerMap . "ca')<CR>", s:a)
        call s:addMapping1(triggerMap . "cI')<CR>", s:I)
        call s:addMapping1(triggerMap . "cA')<CR>", s:A)
        call s:addMapping2(triggerMap . "ni')<CR>", s:i, s:n)
        call s:addMapping2(triggerMap . "na')<CR>", s:a, s:n)
        call s:addMapping2(triggerMap . "nI')<CR>", s:I, s:n)
        call s:addMapping2(triggerMap . "nA')<CR>", s:A, s:n)
        call s:addMapping2(triggerMap . "li')<CR>", s:i, s:l)
        call s:addMapping2(triggerMap . "la')<CR>", s:a, s:l)
        call s:addMapping2(triggerMap . "lI')<CR>", s:I, s:l)
        call s:addMapping2(triggerMap . "lA')<CR>", s:A, s:l)
        call s:addMapping2(triggerMap . "Ni')<CR>", s:i, s:N)
        call s:addMapping2(triggerMap . "Na')<CR>", s:a, s:N)
        call s:addMapping2(triggerMap . "NI')<CR>", s:I, s:N)
        call s:addMapping2(triggerMap . "NA')<CR>", s:A, s:N)
        call s:addMapping2(triggerMap . "Li')<CR>", s:i, s:L)
        call s:addMapping2(triggerMap . "La')<CR>", s:a, s:L)
        call s:addMapping2(triggerMap . "LI')<CR>", s:I, s:L)
        call s:addMapping2(triggerMap . "LA')<CR>", s:A, s:L)
    endfor
endfunction

" separator text objects expand to the right
" cursor  |                   ........
" line    │ a , bbbbb , ccccc , ddddd , eeeee , fffff , g
" command │   ││└IL,┘│││└Il,┘│││└ I,┘│││└In,┘│││└IN,┘│ │
"         │   │└─iL,─┤│├─il,─┤│├─ i,─┤│├─in,─┤│├─iN,─┤ │
"         │   ├──aL,─┘├┼─al,─┘├┼─ a,─┘├┼─an,─┘├┼─aN,─┘ │
"         │   └──AL,──┼┘      └┼─ A,──┼┘      └┼─AN,───┘
"         │           └─ Al, ──┘      └─ An, ──┘
" cursor  │ .........        │       ..........
" line    │ a , bbbb , c , d │ a , b , cccc , d
" command │   ││└I,┘│ │      │       ││└I,┘│ │
"         │   │└─i,─┤ │      │       │└─i,─┤ │
"         │   ├──a,─┘ │      │       ├──a,─┘ │
"         │   └──A,───┘      │       └──A,───┘
function! s:createSeparatorTextObjects()
    " separator text objects
    for trigger in split(g:targets_separators, '\zs')
        if trigger ==# ' '
            continue
        elseif trigger ==# '|'
            let trigger = '\|'
        endif
        let triggerMap = trigger . " :<C-U>call targets#o('" . trigger
        call s:addMapping1(triggerMap . "ci')<CR>", s:i)
        call s:addMapping1(triggerMap . "ca')<CR>", s:a)
        call s:addMapping1(triggerMap . "cI')<CR>", s:I)
        call s:addMapping1(triggerMap . "cA')<CR>", s:A)
        call s:addMapping2(triggerMap . "ni')<CR>", s:i, s:n)
        call s:addMapping2(triggerMap . "na')<CR>", s:a, s:n)
        call s:addMapping2(triggerMap . "nI')<CR>", s:I, s:n)
        call s:addMapping2(triggerMap . "nA')<CR>", s:A, s:n)
        call s:addMapping2(triggerMap . "li')<CR>", s:i, s:l)
        call s:addMapping2(triggerMap . "la')<CR>", s:a, s:l)
        call s:addMapping2(triggerMap . "lI')<CR>", s:I, s:l)
        call s:addMapping2(triggerMap . "lA')<CR>", s:A, s:l)
        call s:addMapping2(triggerMap . "Ni')<CR>", s:i, s:N)
        call s:addMapping2(triggerMap . "Na')<CR>", s:a, s:N)
        call s:addMapping2(triggerMap . "NI')<CR>", s:I, s:N)
        call s:addMapping2(triggerMap . "NA')<CR>", s:A, s:N)
        call s:addMapping2(triggerMap . "Li')<CR>", s:i, s:L)
        call s:addMapping2(triggerMap . "La')<CR>", s:a, s:L)
        call s:addMapping2(triggerMap . "LI')<CR>", s:I, s:L)
        call s:addMapping2(triggerMap . "LA')<CR>", s:A, s:L)
    endfor
endfunction

" argument text objects expand to the right
" cursor  |                          .........
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
function! s:createArgTextObjects()
    let trigger = g:targets_argTrigger
    let triggerMap = trigger . " :<C-U>call targets#o('" . trigger
    call s:addMapping1(triggerMap . "ci')<CR>", s:i)
    call s:addMapping1(triggerMap . "ca')<CR>", s:a)
    call s:addMapping1(triggerMap . "cI')<CR>", s:I)
    call s:addMapping1(triggerMap . "cA')<CR>", s:A)
    call s:addMapping2(triggerMap . "ni')<CR>", s:i, s:n)
    call s:addMapping2(triggerMap . "na')<CR>", s:a, s:n)
    call s:addMapping2(triggerMap . "nI')<CR>", s:I, s:n)
    call s:addMapping2(triggerMap . "nA')<CR>", s:A, s:n)
    call s:addMapping2(triggerMap . "li')<CR>", s:i, s:l)
    call s:addMapping2(triggerMap . "la')<CR>", s:a, s:l)
    call s:addMapping2(triggerMap . "lI')<CR>", s:I, s:l)
    call s:addMapping2(triggerMap . "lA')<CR>", s:A, s:l)
endfunction

" add expression mappings for `A` and `I` in visual mode #23 unless
" deactivated #49
function! s:addExpressionMappings()
    silent! execute 'xnoremap <expr> <silent> <unique> ' . s:i . " targets#e('i')"
    silent! execute 'xnoremap <expr> <silent> <unique> ' . s:a . " targets#e('a')"
    silent! execute 'xnoremap <expr> <silent> <unique> ' . s:I . " targets#e('I')"
    silent! execute 'xnoremap <expr> <silent> <unique> ' . s:A . " targets#e('A')"
endfunction

function! s:loadSettings()
    if !exists('g:targets_aiAI')
        let g:targets_aiAI = 'aiAI'
    endif
    if !exists('g:targets_nlNL')
        let g:targets_nlNL = 'nlNL'
    endif
    if !exists('g:targets_pairs')
        let g:targets_pairs = '()b {}B [] <>'
    endif
    if !exists('g:targets_quotes')
        let g:targets_quotes = '" '' `'
    endif
    if !exists('g:targets_separators')
        let g:targets_separators = ', . ; : + - = ~ _ * # / \ | & $'
    endif
    if !exists('g:targets_tagTrigger')
        let g:targets_tagTrigger = 't'
    endif
    if !exists('g:targets_argTrigger')
        let g:targets_argTrigger = 'a'
    endif
    if !exists('g:targets_argOpening')
        let g:targets_argOpening = '[([]'
    endif
    if !exists('g:targets_argClosing')
        let g:targets_argClosing = '[])]'
    endif
    if !exists('g:targets_argSeparator')
        let g:targets_argSeparator = ','
    endif

    let [s:a, s:i, s:A, s:I] = split(g:targets_aiAI, '\zs')
    let [s:n, s:l, s:N, s:L] = split(g:targets_nlNL, '\zs')
endfunction

call s:loadSettings()

" create the text objects (current total count: 528)
call s:createPairTextObjects()
call s:createTagTextObjects()
call s:createQuoteTextObjects()
call s:createSeparatorTextObjects()
call s:createArgTextObjects()
call s:addExpressionMappings()

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
