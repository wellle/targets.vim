" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license
" Updated: 2014-08-21
" Version: 0.3.0

if exists("g:loaded_targets") || &cp || v:version < 700
    finish
endif
let g:loaded_targets = '0.3.0' " version number
let s:save_cpoptions = &cpoptions
set cpo&vim

" create a text object by combining prefix and trigger to call Match with
" the given delimiters and matchers
function! s:createTextObject(prefix, trigger, delimiters, matchers)
    if match(a:prefix, ' ') >= 0  " if there's a blank in the prefix, it should be deactivated
        return
    endif

    let delimiters = substitute(a:delimiters, "'", "''", 'g')

    let rawMapping = a:prefix . a:trigger
    let rawArguments = "'" . delimiters . "', '" . a:matchers . "'"

    let mapping = substitute(rawMapping, '|', '\\\|', 'g')
    let arguments = substitute(rawArguments, '|', '\\\|', 'g')

    execute 'onoremap <silent>' . mapping . ' :<C-U>call targets#omap(' . arguments . ')<CR>'

    " don't create xmaps beginning with `A` or `I`
    " conflict with `^VA` and `^VI` to append before or insert after visual
    " block selection. #6
    " instead, save mapping to targets_mapArgs so we can execute these only
    " for character wise visual mode in targets#uppercaseXmap #23
    if a:prefix !~# '^[AI]'
        execute 'xnoremap <silent>' . mapping . ' :<C-U>call targets#xmap(' . arguments . ')<CR>'
    else
        let g:targets_mapArgs[rawMapping] = rawArguments
    endif

    unlet delimiters mapping arguments
endfunction

" create a text object for a single delimiter
function! s:createSimpleTextObject(prefix, delimiter, matchers)
    call s:createTextObject(a:prefix, a:delimiter[0], a:delimiter[0], a:matchers)
    if strlen(a:delimiter) > 1  " check for alias
        call s:createTextObject(a:prefix, a:delimiter[1], a:delimiter[0], a:matchers)
    endif
endfunction

" create multiple text objects for a pair of delimiters and optional
" additional triggers
function! s:createPairTextObject(prefix, delimiters, matchers)
    let [opening, closing] = [a:delimiters[0], a:delimiters[1]]
    for trigger in split(a:delimiters, '\zs')
        call s:createTextObject(a:prefix, trigger, opening . closing, a:matchers)
    endfor
    unlet opening closing
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
        let triggerMap = trigger . " :<C-U>call targets#o('p" . trigger
        execute 'onoremap <silent>' . s:i       . triggerMap . "ci')<CR>"
        execute 'onoremap <silent>' . s:a       . triggerMap . "ca')<CR>"
        execute 'onoremap <silent>' . s:I       . triggerMap . "cI')<CR>"
        execute 'onoremap <silent>' . s:A       . triggerMap . "cA')<CR>"
        execute 'onoremap <silent>' . s:i . s:n . triggerMap . "ni')<CR>"
        execute 'onoremap <silent>' . s:a . s:n . triggerMap . "na')<CR>"
        execute 'onoremap <silent>' . s:I . s:n . triggerMap . "nI')<CR>"
        execute 'onoremap <silent>' . s:A . s:n . triggerMap . "nA')<CR>"
        execute 'onoremap <silent>' . s:i . s:l . triggerMap . "li')<CR>"
        execute 'onoremap <silent>' . s:a . s:l . triggerMap . "la')<CR>"
        execute 'onoremap <silent>' . s:I . s:l . triggerMap . "lI')<CR>"
        execute 'onoremap <silent>' . s:A . s:l . triggerMap . "lA')<CR>"
    endfor
endfunction

" tag text objects work on tags (similar to pair text objects)
function! s:createTagTextObjects()
    let triggerMap = "t :<C-U>call targets#o('t"
    execute 'onoremap <silent>' . s:i       . triggerMap . "tci')<CR>"
    execute 'onoremap <silent>' . s:a       . triggerMap . "tca')<CR>"
    execute 'onoremap <silent>' . s:I       . triggerMap . "tcI')<CR>"
    execute 'onoremap <silent>' . s:A       . triggerMap . "tcA')<CR>"
    execute 'onoremap <silent>' . s:i . s:n . triggerMap . "tni')<CR>"
    execute 'onoremap <silent>' . s:a . s:n . triggerMap . "tna')<CR>"
    execute 'onoremap <silent>' . s:I . s:n . triggerMap . "tnI')<CR>"
    execute 'onoremap <silent>' . s:A . s:n . triggerMap . "tnA')<CR>"
    execute 'onoremap <silent>' . s:i . s:l . triggerMap . "tli')<CR>"
    execute 'onoremap <silent>' . s:a . s:l . triggerMap . "tla')<CR>"
    execute 'onoremap <silent>' . s:I . s:l . triggerMap . "tlI')<CR>"
    execute 'onoremap <silent>' . s:A . s:l . triggerMap . "tlA')<CR>"
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
            let triggerMap = "' :<C-U>call targets#o('q''"
        else
            let triggerMap = trigger . " :<C-U>call targets#o('q" . trigger
        endif
        execute 'onoremap <silent>' . s:i       . triggerMap . "ci')<CR>"
        execute 'onoremap <silent>' . s:a       . triggerMap . "ca')<CR>"
        execute 'onoremap <silent>' . s:I       . triggerMap . "cI')<CR>"
        execute 'onoremap <silent>' . s:A       . triggerMap . "cA')<CR>"
        execute 'onoremap <silent>' . s:i . s:n . triggerMap . "ni')<CR>"
        execute 'onoremap <silent>' . s:a . s:n . triggerMap . "na')<CR>"
        execute 'onoremap <silent>' . s:I . s:n . triggerMap . "nI')<CR>"
        execute 'onoremap <silent>' . s:A . s:n . triggerMap . "nA')<CR>"
        execute 'onoremap <silent>' . s:i . s:l . triggerMap . "li')<CR>"
        execute 'onoremap <silent>' . s:a . s:l . triggerMap . "la')<CR>"
        execute 'onoremap <silent>' . s:I . s:l . triggerMap . "lI')<CR>"
        execute 'onoremap <silent>' . s:A . s:l . triggerMap . "lA')<CR>"
        execute 'onoremap <silent>' . s:i . s:N . triggerMap . "Ni')<CR>"
        execute 'onoremap <silent>' . s:a . s:N . triggerMap . "Na')<CR>"
        execute 'onoremap <silent>' . s:I . s:N . triggerMap . "NI')<CR>"
        execute 'onoremap <silent>' . s:A . s:N . triggerMap . "NA')<CR>"
        execute 'onoremap <silent>' . s:i . s:L . triggerMap . "Li')<CR>"
        execute 'onoremap <silent>' . s:a . s:L . triggerMap . "La')<CR>"
        execute 'onoremap <silent>' . s:I . s:L . triggerMap . "LI')<CR>"
        execute 'onoremap <silent>' . s:A . s:L . triggerMap . "LA')<CR>"
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
        let triggerMap = trigger . " :<C-U>call targets#o('s" . trigger
        execute 'onoremap <silent>' . s:i       . triggerMap . "ci')<CR>"
        execute 'onoremap <silent>' . s:a       . triggerMap . "ca')<CR>"
        execute 'onoremap <silent>' . s:I       . triggerMap . "cI')<CR>"
        execute 'onoremap <silent>' . s:A       . triggerMap . "cA')<CR>"
        execute 'onoremap <silent>' . s:i . s:n . triggerMap . "ni')<CR>"
        execute 'onoremap <silent>' . s:a . s:n . triggerMap . "na')<CR>"
        execute 'onoremap <silent>' . s:I . s:n . triggerMap . "nI')<CR>"
        execute 'onoremap <silent>' . s:A . s:n . triggerMap . "nA')<CR>"
        execute 'onoremap <silent>' . s:i . s:l . triggerMap . "li')<CR>"
        execute 'onoremap <silent>' . s:a . s:l . triggerMap . "la')<CR>"
        execute 'onoremap <silent>' . s:I . s:l . triggerMap . "lI')<CR>"
        execute 'onoremap <silent>' . s:A . s:l . triggerMap . "lA')<CR>"
        execute 'onoremap <silent>' . s:i . s:N . triggerMap . "Ni')<CR>"
        execute 'onoremap <silent>' . s:a . s:N . triggerMap . "Na')<CR>"
        execute 'onoremap <silent>' . s:I . s:N . triggerMap . "NI')<CR>"
        execute 'onoremap <silent>' . s:A . s:N . triggerMap . "NA')<CR>"
        execute 'onoremap <silent>' . s:i . s:L . triggerMap . "Li')<CR>"
        execute 'onoremap <silent>' . s:a . s:L . triggerMap . "La')<CR>"
        execute 'onoremap <silent>' . s:I . s:L . triggerMap . "LI')<CR>"
        execute 'onoremap <silent>' . s:A . s:L . triggerMap . "LA')<CR>"
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
    let triggerMap = "a :<C-U>call targets#o('a"
    execute 'onoremap <silent>' . s:i       . triggerMap . " ci')<CR>"
    execute 'onoremap <silent>' . s:a       . triggerMap . " ca')<CR>"
    execute 'onoremap <silent>' . s:I       . triggerMap . " cI')<CR>"
    execute 'onoremap <silent>' . s:A       . triggerMap . " cA')<CR>"
    execute 'onoremap <silent>' . s:i . s:n . triggerMap . " ni')<CR>"
    execute 'onoremap <silent>' . s:a . s:n . triggerMap . " na')<CR>"
    execute 'onoremap <silent>' . s:I . s:n . triggerMap . " nI')<CR>"
    execute 'onoremap <silent>' . s:A . s:n . triggerMap . " nA')<CR>"
    execute 'onoremap <silent>' . s:i . s:l . triggerMap . " li')<CR>"
    execute 'onoremap <silent>' . s:a . s:l . triggerMap . " la')<CR>"
    execute 'onoremap <silent>' . s:I . s:l . triggerMap . " lI')<CR>"
    execute 'onoremap <silent>' . s:A . s:l . triggerMap . " lA')<CR>"
endfunction

" add expression mappings for `A` and `I` in visual mode #23 unless
" deactivated #49
function! s:addExpressionMappings()
    if s:A !=# ' '
        xnoremap <expr> <silent> A targets#uppercaseXmap('A')
    endif
    if s:I !=# ' '
        xnoremap <expr> <silent> I targets#uppercaseXmap('I')
    endif
endfunction

function! s:loadSettings()
    " load configuration options if present
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

" create the text objects (current total count: 536)
call s:createPairTextObjects()
call s:createTagTextObjects()
call s:createQuoteTextObjects()
call s:createSeparatorTextObjects()
call s:createArgTextObjects()
call s:addExpressionMappings()

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
