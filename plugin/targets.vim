" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license
" Updated: 2014-02-24
" Version: 0.0.4

if exists("g:loaded_targets") || &cp || v:version < 700
    finish
endif
let g:loaded_targets = '0.0.4' " version number
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
    " instead, save mapping to targets#mapArgs so we can execute these only
    " for character wise visual mode in targets#uppercaseXmap #23
    if a:prefix !~# '^[AI]'
        execute 'xnoremap <silent>' . mapping . ' :<C-U>call targets#xmap(' . arguments . ')<CR>'
    else
        let g:targets#mapArgs[rawMapping] = rawArguments
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
        call s:createPairTextObject(s:I,  delimiters, 'seek selectp shrink')
        call s:createPairTextObject(s:i,  delimiters, 'seek selectp drop')
        call s:createPairTextObject(s:a,  delimiters, 'seek selectp')
        call s:createPairTextObject(s:A,  delimiters, 'seek selectp expand')
        call s:createPairTextObject(s:I . s:n, delimiters, 'nextp selectp shrink')
        call s:createPairTextObject(s:i . s:n, delimiters, 'nextp selectp drop')
        call s:createPairTextObject(s:a . s:n, delimiters, 'nextp selectp')
        call s:createPairTextObject(s:A . s:n, delimiters, 'nextp selectp expand')
        call s:createPairTextObject(s:I . s:l, delimiters, 'lastp selectp shrink')
        call s:createPairTextObject(s:i . s:l, delimiters, 'lastp selectp drop')
        call s:createPairTextObject(s:a . s:l, delimiters, 'lastp selectp')
        call s:createPairTextObject(s:A . s:l, delimiters, 'lastp selectp expand')
    endfor
endfunction

" quote text objects expand into quote (by counting quote signs)
" `aN'` is a shortcut for `2an'` to jump from within one quote into the
" next one, instead of the quote in between
" cursor  │                   ........
" line    │ a ' bbbbb ' ccccc ' dddd ' eeeee ' fffff ' g
" command │   ││└IL'┘│││└Il'┘│││└I'┘│││└In'┘│││└IN'┘│ │
"         │   │└─iL'─┘│├─il'─┘│├─i'─┘│├─in'─┘│├─iN'─┘ │
"         │   └──aL'──┼┘      └┼─a'──┼┘      └┼─aN'───┘
"         │           └──al'───┘     └──an'───┘
" cursor  │ ..........      │      ......      │      ..........
" line    │ a ' bbbb ' c '' │ ' a ' bbbb ' c ' │ '' b ' cccc ' d
" command │   ││└I'┘│ │     │     ││└I'┘│ │    │      ││└I'┘│ │
"         │   │└─i'─┘ │     │     │└─i'─┘ │    │      │└─i'─┘ │
"         │   └──a'───┘     │     └──a'───┘    │      └──a'───┘
function! s:createQuoteTextObjects()
    for delimiter in s:quote_list
        call s:createSimpleTextObject(s:I,  delimiter, 'quote seek select shrink')
        call s:createSimpleTextObject(s:i,  delimiter, 'quote seek select drop')
        call s:createSimpleTextObject(s:a,  delimiter, 'quote seek select expand')
        call s:createSimpleTextObject(s:I . s:n, delimiter, 'quote next select shrink')
        call s:createSimpleTextObject(s:i . s:n, delimiter, 'quote next select drop')
        call s:createSimpleTextObject(s:a . s:n, delimiter, 'quote next select expand')
        call s:createSimpleTextObject(s:I . s:l, delimiter, 'quote last select shrink')
        call s:createSimpleTextObject(s:i . s:l, delimiter, 'quote last select drop')
        call s:createSimpleTextObject(s:a . s:l, delimiter, 'quote last select expand')
        call s:createSimpleTextObject(s:I . s:N, delimiter, 'quote double next select shrink')
        call s:createSimpleTextObject(s:i . s:N, delimiter, 'quote double next select drop')
        call s:createSimpleTextObject(s:a . s:N, delimiter, 'quote double next select expand')
        call s:createSimpleTextObject(s:I . s:L, delimiter, 'quote double last select shrink')
        call s:createSimpleTextObject(s:i . s:L, delimiter, 'quote double last select drop')
        call s:createSimpleTextObject(s:a . s:L, delimiter, 'quote double last select expand')
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
        call s:createSimpleTextObject(s:I,  delimiter, 'seek select shrink')
        call s:createSimpleTextObject(s:i,  delimiter, 'seek select drop')
        call s:createSimpleTextObject(s:a,  delimiter, 'seek select dropr')
        call s:createSimpleTextObject(s:A,  delimiter, 'seek select expand')
        call s:createSimpleTextObject(s:I . s:n, delimiter, 'next select shrink')
        call s:createSimpleTextObject(s:i . s:n, delimiter, 'next select drop')
        call s:createSimpleTextObject(s:a . s:n, delimiter, 'next select dropr')
        call s:createSimpleTextObject(s:A . s:n, delimiter, 'next select expand')
        call s:createSimpleTextObject(s:I . s:l, delimiter, 'last select shrink')
        call s:createSimpleTextObject(s:i . s:l, delimiter, 'last select drop')
        call s:createSimpleTextObject(s:a . s:l, delimiter, 'last select dropr')
        call s:createSimpleTextObject(s:A . s:l, delimiter, 'last select expand')
        call s:createSimpleTextObject(s:I . s:N, delimiter, 'double next select shrink')
        call s:createSimpleTextObject(s:i . s:N, delimiter, 'double next select drop')
        call s:createSimpleTextObject(s:a . s:N, delimiter, 'double next select dropr')
        call s:createSimpleTextObject(s:A . s:N, delimiter, 'double next select expand')
        call s:createSimpleTextObject(s:I . s:L, delimiter, 'double last select shrink')
        call s:createSimpleTextObject(s:i . s:L, delimiter, 'double last select drop')
        call s:createSimpleTextObject(s:a . s:L, delimiter, 'double last select dropr')
        call s:createSimpleTextObject(s:A . s:L, delimiter, 'double last select expand')
    endfor
endfunction

" add expression mappings for `A` and `I` in visual mode #23
function! s:addExpressionMappings()
    xnoremap <expr> <silent> A targets#uppercaseXmap('A')
    xnoremap <expr> <silent> I targets#uppercaseXmap('I')
endfunction

function! s:loadSettings()
    " load configuration options if present
    let s:custom_aiAI        = exists('g:targets_aiAI')
    let s:custom_nlNL        = exists('g:targets_nlNL')

    let s:a = (s:custom_aiAI ? g:targets_aiAI[0] : 'a')
    let s:i = (s:custom_aiAI ? g:targets_aiAI[1] : 'i')
    let s:A = (s:custom_aiAI ? g:targets_aiAI[2] : 'A')
    let s:I = (s:custom_aiAI ? g:targets_aiAI[3] : 'I')

    let s:n = (s:custom_nlNL ? g:targets_nlNL[0] : 'n')
    let s:l = (s:custom_nlNL ? g:targets_nlNL[1] : 'l')
    let s:N = (s:custom_nlNL ? g:targets_nlNL[2] : 'N')
    let s:L = (s:custom_nlNL ? g:targets_nlNL[3] : 'L')

    let s:pair_list = exists('g:targets_pairs')
                \? split(g:targets_pairs)
                \: ['()b', '{}B', '[]r', '<>a']
    let s:quote_list = exists('g:targets_quotes')
                \? split(g:targets_quotes)
                \: [ "'", '"', '`' ]
    let s:separator_list = exists('g:targets_separators')
                \? split(g:targets_separators)
                \: [ ',', '.', ';', ':', '+', '-', '~', '_', '*', '/', '\', '|' ]
endfunction

" dictionary mapping uppercase xmap like `An,` to argument strings for
" targets#xmapCount. used by targets#uppercaseXmap
let targets#mapArgs = {}

call s:loadSettings()

" create the text objects (current total count: 429)
call s:createPairTextObjects()
call s:createQuoteTextObjects()
call s:createSeparatorTextObjects()
call s:addExpressionMappings()

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
