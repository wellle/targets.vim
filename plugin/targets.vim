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
    call s:createTextObject(a:prefix, a:delimiter, a:delimiter, a:matchers)
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
    for delimiters in [ '()b', '{}B', '[]r', '<>a' ] " aliases like surround
        call s:createPairTextObject('I',  delimiters, 'seek selectp shrink')
        call s:createPairTextObject('i',  delimiters, 'seek selectp drop')
        call s:createPairTextObject('a',  delimiters, 'seek selectp')
        call s:createPairTextObject('A',  delimiters, 'seek selectp expand')
        call s:createPairTextObject('In', delimiters, 'nextp selectp shrink')
        call s:createPairTextObject('in', delimiters, 'nextp selectp drop')
        call s:createPairTextObject('an', delimiters, 'nextp selectp')
        call s:createPairTextObject('An', delimiters, 'nextp selectp expand')
        call s:createPairTextObject('Il', delimiters, 'lastp selectp shrink')
        call s:createPairTextObject('il', delimiters, 'lastp selectp drop')
        call s:createPairTextObject('al', delimiters, 'lastp selectp')
        call s:createPairTextObject('Al', delimiters, 'lastp selectp expand')
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
    for delimiter in [ "'", '"', '`' ]
        call s:createSimpleTextObject('I',  delimiter, 'quote seek select shrink')
        call s:createSimpleTextObject('i',  delimiter, 'quote seek select drop')
        call s:createSimpleTextObject('a',  delimiter, 'quote seek select expand')
        call s:createSimpleTextObject('In', delimiter, 'quote next select shrink')
        call s:createSimpleTextObject('in', delimiter, 'quote next select drop')
        call s:createSimpleTextObject('an', delimiter, 'quote next select expand')
        call s:createSimpleTextObject('Il', delimiter, 'quote last select shrink')
        call s:createSimpleTextObject('il', delimiter, 'quote last select drop')
        call s:createSimpleTextObject('al', delimiter, 'quote last select expand')
        call s:createSimpleTextObject('IN', delimiter, 'quote double next select shrink')
        call s:createSimpleTextObject('iN', delimiter, 'quote double next select drop')
        call s:createSimpleTextObject('aN', delimiter, 'quote double next select expand')
        call s:createSimpleTextObject('IL', delimiter, 'quote double last select shrink')
        call s:createSimpleTextObject('iL', delimiter, 'quote double last select drop')
        call s:createSimpleTextObject('aL', delimiter, 'quote double last select expand')
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
    for delimiter in [ ',', '.', ';', ':', '+', '-', '~', '_', '*', '/', '\', '|' ]
        call s:createSimpleTextObject('I',  delimiter, 'seek select shrink')
        call s:createSimpleTextObject('i',  delimiter, 'seek select drop')
        call s:createSimpleTextObject('a',  delimiter, 'seek select dropr')
        call s:createSimpleTextObject('A',  delimiter, 'seek select expand')
        call s:createSimpleTextObject('In', delimiter, 'next select shrink')
        call s:createSimpleTextObject('in', delimiter, 'next select drop')
        call s:createSimpleTextObject('an', delimiter, 'next select dropr')
        call s:createSimpleTextObject('An', delimiter, 'next select expand')
        call s:createSimpleTextObject('Il', delimiter, 'last select shrink')
        call s:createSimpleTextObject('il', delimiter, 'last select drop')
        call s:createSimpleTextObject('al', delimiter, 'last select dropr')
        call s:createSimpleTextObject('Al', delimiter, 'last select expand')
        call s:createSimpleTextObject('IN', delimiter, 'double next select shrink')
        call s:createSimpleTextObject('iN', delimiter, 'double next select drop')
        call s:createSimpleTextObject('aN', delimiter, 'double next select dropr')
        call s:createSimpleTextObject('AN', delimiter, 'double next select expand')
        call s:createSimpleTextObject('IL', delimiter, 'double last select shrink')
        call s:createSimpleTextObject('iL', delimiter, 'double last select drop')
        call s:createSimpleTextObject('aL', delimiter, 'double last select dropr')
        call s:createSimpleTextObject('AL', delimiter, 'double last select expand')
    endfor
endfunction

" add expression mappings for `A` and `I` in visual mode #23
function! s:addExpressionMappings()
    xnoremap <expr> <silent> A targets#uppercaseXmap('A')
    xnoremap <expr> <silent> I targets#uppercaseXmap('I')
endfunction

" dictionary mapping uppercase xmap like `An,` to argument strings for
" targets#xmapCount. used by targets#uppercaseXmap
let targets#mapArgs = {}

" create the text objects (current total count: 429)
call s:createPairTextObjects()
call s:createQuoteTextObjects()
call s:createSeparatorTextObjects()
call s:addExpressionMappings()

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
