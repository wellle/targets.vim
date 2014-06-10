" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license
" Updated: 2014-06-14
" Version: 0.2.7

if exists("g:loaded_targets") || &cp || v:version < 700
    finish
endif
let g:loaded_targets = '0.2.7' " version number
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

" creat a text object for a single delimiter
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
    for delimiters in s:pair_list " aliases like surround
        call s:createPairTextObject(s:i,       delimiters, 'grow seekselectp drop')
        call s:createPairTextObject(s:a,       delimiters, 'grow seekselectp')
        call s:createPairTextObject(s:I,       delimiters, 'seekselectp shrink')
        call s:createPairTextObject(s:A,       delimiters, 'seekselectp expand')
        call s:createPairTextObject(s:i . s:n, delimiters, 'nextp selectp drop')
        call s:createPairTextObject(s:a . s:n, delimiters, 'nextp selectp')
        call s:createPairTextObject(s:I . s:n, delimiters, 'nextp selectp shrink')
        call s:createPairTextObject(s:A . s:n, delimiters, 'nextp selectp expand')
        call s:createPairTextObject(s:i . s:l, delimiters, 'lastp selectp drop')
        call s:createPairTextObject(s:a . s:l, delimiters, 'lastp selectp')
        call s:createPairTextObject(s:I . s:l, delimiters, 'lastp selectp shrink')
        call s:createPairTextObject(s:A . s:l, delimiters, 'lastp selectp expand')
    endfor
endfunction

" tag text objects work on tags (similar to pair text objects)
function! s:createTagTextObjects()
    call s:createSimpleTextObject(s:i,       't', 'grow seekselectt innert drop')
    call s:createSimpleTextObject(s:a,       't', 'grow seekselectt')
    call s:createSimpleTextObject(s:I,       't', 'seekselectt innert shrink')
    call s:createSimpleTextObject(s:A,       't', 'seekselectt expand')
    call s:createSimpleTextObject(s:i . s:n, 't', 'nextt selectp innert drop')
    call s:createSimpleTextObject(s:a . s:n, 't', 'nextt selectp')
    call s:createSimpleTextObject(s:I . s:n, 't', 'nextt selectp innert shrink')
    call s:createSimpleTextObject(s:A . s:n, 't', 'nextt selectp expand')
    call s:createSimpleTextObject(s:i . s:l, 't', 'lastt selectp innert drop')
    call s:createSimpleTextObject(s:a . s:l, 't', 'lastt selectp')
    call s:createSimpleTextObject(s:I . s:l, 't', 'lastt selectp innert shrink')
    call s:createSimpleTextObject(s:A . s:l, 't', 'lastt selectp expand')
endfunction

" TODO: create more argument mappings
" TODO: implement growing?
" TODO: no seeking?
" TODO: skip top level commas () , ()
" TODO: reorder
function! s:createArgTextObjects()
    call s:createSimpleTextObject(s:i      , 'a', 'grow seekselecta drop')
    call s:createSimpleTextObject(s:a      , 'a', 'grow seekselecta dropa')
    call s:createSimpleTextObject(s:I      , 'a', 'grow seekselecta shrink')
    call s:createSimpleTextObject(s:A      , 'a', 'grow seekselecta expand')
    call s:createSimpleTextObject(s:i . s:n, 'a', 'nextselecta drop')
    call s:createSimpleTextObject(s:a . s:n, 'a', 'nextselecta dropa')
    call s:createSimpleTextObject(s:I . s:n, 'a', 'nextselecta shrink')
    call s:createSimpleTextObject(s:A . s:n, 'a', 'nextselecta expand')
    call s:createSimpleTextObject(s:i . s:l, 'a', 'lastselecta drop')
    call s:createSimpleTextObject(s:a . s:l, 'a', 'lastselecta dropa')
    call s:createSimpleTextObject(s:I . s:l, 'a', 'lastselecta shrink')
    call s:createSimpleTextObject(s:A . s:l, 'a', 'lastselecta expand')
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
    for delimiter in s:quote_list
        call s:createSimpleTextObject(s:i,       delimiter, 'quote seekselect drop')
        call s:createSimpleTextObject(s:a,       delimiter, 'quote seekselect')
        call s:createSimpleTextObject(s:I,       delimiter, 'quote seekselect shrink')
        call s:createSimpleTextObject(s:A,       delimiter, 'quote seekselect expand')
        call s:createSimpleTextObject(s:i . s:n, delimiter, 'quote nextselect drop')
        call s:createSimpleTextObject(s:a . s:n, delimiter, 'quote nextselect')
        call s:createSimpleTextObject(s:I . s:n, delimiter, 'quote nextselect shrink')
        call s:createSimpleTextObject(s:A . s:n, delimiter, 'quote nextselect expand')
        call s:createSimpleTextObject(s:i . s:l, delimiter, 'quote lastselect drop')
        call s:createSimpleTextObject(s:a . s:l, delimiter, 'quote lastselect')
        call s:createSimpleTextObject(s:I . s:l, delimiter, 'quote lastselect shrink')
        call s:createSimpleTextObject(s:A . s:l, delimiter, 'quote lastselect expand')
        call s:createSimpleTextObject(s:i . s:N, delimiter, 'quote double nextselect drop')
        call s:createSimpleTextObject(s:a . s:N, delimiter, 'quote double nextselect')
        call s:createSimpleTextObject(s:I . s:N, delimiter, 'quote double nextselect shrink')
        call s:createSimpleTextObject(s:A . s:N, delimiter, 'quote double nextselect expand')
        call s:createSimpleTextObject(s:i . s:L, delimiter, 'quote double lastselect drop')
        call s:createSimpleTextObject(s:a . s:L, delimiter, 'quote double lastselect')
        call s:createSimpleTextObject(s:I . s:L, delimiter, 'quote double lastselect shrink')
        call s:createSimpleTextObject(s:A . s:L, delimiter, 'quote double lastselect expand')
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
"         | nsth |
function! s:createSeparatorTextObjects()
    for delimiter in s:separator_list
        let [ delimiter, dropr ] = s:parseDelimiter(delimiter)

        call s:createSimpleTextObject(s:i,       delimiter, 'seekselect drop')
        call s:createSimpleTextObject(s:a,       delimiter, 'seekselect' . dropr)
        call s:createSimpleTextObject(s:I,       delimiter, 'seekselect shrink')
        call s:createSimpleTextObject(s:A,       delimiter, 'seekselect expand')
        call s:createSimpleTextObject(s:i . s:n, delimiter, 'nextselect drop')
        call s:createSimpleTextObject(s:a . s:n, delimiter, 'nextselect' . dropr)
        call s:createSimpleTextObject(s:I . s:n, delimiter, 'nextselect shrink')
        call s:createSimpleTextObject(s:A . s:n, delimiter, 'nextselect expand')
        call s:createSimpleTextObject(s:i . s:l, delimiter, 'lastselect drop')
        call s:createSimpleTextObject(s:a . s:l, delimiter, 'lastselect' . dropr)
        call s:createSimpleTextObject(s:I . s:l, delimiter, 'lastselect shrink')
        call s:createSimpleTextObject(s:A . s:l, delimiter, 'lastselect expand')
        call s:createSimpleTextObject(s:i . s:N, delimiter, 'double nextselect drop')
        call s:createSimpleTextObject(s:a . s:N, delimiter, 'double nextselect' . dropr)
        call s:createSimpleTextObject(s:I . s:N, delimiter, 'double nextselect shrink')
        call s:createSimpleTextObject(s:A . s:N, delimiter, 'double nextselect expand')
        call s:createSimpleTextObject(s:i . s:L, delimiter, 'double lastselect drop')
        call s:createSimpleTextObject(s:a . s:L, delimiter, 'double lastselect' . dropr)
        call s:createSimpleTextObject(s:I . s:L, delimiter, 'double lastselect shrink')
        call s:createSimpleTextObject(s:A . s:L, delimiter, 'double lastselect expand')
    endfor
endfunction

function! s:parseDelimiter(delimiter)
    if len(a:delimiter) >= 2 && a:delimiter[0] == a:delimiter[1] " delimiter is doubled
        return [ a:delimiter[1:], '' ] " remove first double, don't drop right separator
    endif

    return [ a:delimiter, ' dropr' ] " drop right delimiter (default)
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
        let g:targets_pairs = '()b {}B []r <>'
    endif
    if !exists('g:targets_quotes')
        let g:targets_quotes = '" '' `'
    endif
    if !exists('g:targets_separators')
        let g:targets_separators = ', . ; : + - = ~ _ * # / \ | & $'
    endif

    let [s:a, s:i, s:A, s:I] = split(g:targets_aiAI, '\zs')
    let [s:n, s:l, s:N, s:L] = split(g:targets_nlNL, '\zs')

    let s:pair_list = split(g:targets_pairs)
    let s:quote_list = split(g:targets_quotes)
    let s:separator_list = split(g:targets_separators)

    " TODO: document
    let g:targets_argOpening = '[({[]'
    let g:targets_argClosing = '[]})]'
    let g:targets_argOpeningSep = '[,({[]'
    let g:targets_argClosingSep = '[]}),]'
endfunction

" dictionary mapping uppercase xmap like `An,` to argument strings for
" targets#xmapCount. used by targets#uppercaseXmap
let targets_mapArgs = {}

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
