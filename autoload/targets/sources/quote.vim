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
let s:defaultQuoteDirs = get(g:, 'targets_quoteDirs', {
            \ 'r1n': ['001', '201', '100', '102'],
            \ 'r1l': ['010', '012', '111', '210', '212'],
            \ 'r2n': ['101'],
            \ 'r2l': ['011', '211'],
            \ 'r2b': ['000'],
            \ 'l2r': ['110', '112'],
            \ 'n2b': ['002', '200', '202'],
            \ })

function! targets#sources#quote#new(args)
    let quoteDirsConf = get(a:args, 'quoteDirs', s:defaultQuoteDirs)
    let quoteDirs = {}
    for key in keys(s:quoteArgs)
        let quoteArgs = s:quoteArgs[key]
        for rep in get(quoteDirsConf, key, [])
            let quoteDirs[rep] = quoteArgs
        endfor
    endfor

    return {
                \ 'args': {
                \     'delimiter': s:quoteEscape(a:args['d']),
                \     'quoteDirs': quoteDirs
                \ },
                \ 'genFuncs': {
                \     'c': function('targets#sources#quote#current'),
                \     'n': function('targets#sources#quote#next'),
                \     'l': function('targets#sources#quote#last'),
                \ },
                \ 'modFuncs': {
                \     'i': function('targets#modify#drop'),
                \     'a': function('targets#modify#keep'),
                \     'I': function('targets#modify#shrink'),
                \     'A': function('targets#modify#expand'),
                \ }}
endfunction

function! targets#sources#quote#current(args, opts, state)
    if !a:opts.first
        return targets#target#withError('only one current quote')
    endif

    let dir = s:quoteDir(a:args.quoteDirs, a:args.delimiter)[0]
    return targets#util#select(a:args.delimiter, a:args.delimiter, dir)
endfunction

function! targets#sources#quote#next(args, opts, state)
    if !exists('a:state.rate')
        let [_, a:state.rate, _, skipR, _] = s:quoteDir(a:args.quoteDirs, a:args.delimiter)
        let cnt = a:state.rate - skipR " skip initially once
        " echom 'skip'
    else
        let cnt = a:state.rate " then go by rate
        " echom 'no skip'
    endif

    if targets#util#search(a:args.delimiter, 'W', cnt) > 0
        return targets#target#withError('QN')
    endif

    let target = targets#util#select(a:args.delimiter, a:args.delimiter, '>')
    call target.cursorS() " keep going from left end
    return target
endfunction

function! targets#sources#quote#last(args, opts, state)
    if !exists('a:state.rate')
        let [_, a:state.rate, skipL, _, _] = s:quoteDir(a:args.quoteDirs, a:args.delimiter)
        let cnt = a:state.rate - skipL " skip initially once
        " echom 'skip'
    else
        let cnt = a:state.rate " then go by rate
        " echom 'no skip'
    endif

    if targets#util#search(a:args.delimiter, 'bW', cnt) > 0
        return targets#target#withError('QL')
    endif

    let target = targets#util#select(a:args.delimiter, a:args.delimiter, '<')
    call target.cursorE() " keep going from right end
    return target
endfunction

" returns [dir, rate, skipL, skipR, error]
function! s:quoteDir(quoteDirs, delimiter)
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
    let [dir, rate, skipL, skipR, error] = get(a:quoteDirs, key, defaultValues)
    return [dir, rate, skipL, skipR, error]
endfunction

function! s:count(char, text)
    return len(split(a:text, a:char, 1)) - 1
endfunction

function! s:quoteEscape(delimiter)
    if &quoteescape ==# ''
        return a:delimiter
    endif

    let escapedqe = escape(&quoteescape, ']^-\')
    let lookbehind = '[' . escapedqe . ']'
    if v:version >= 704
        return lookbehind . '\@1<!' . a:delimiter
    else
        return lookbehind . '\@<!'  . a:delimiter
    endif
endfunction
