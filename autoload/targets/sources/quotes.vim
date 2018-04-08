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

function! targets#sources#quotes#new(delimiter, ...)
    let quoteDirsConf = a:0 > 0 ? a:1 : g:targets_quoteDirs

    let quoteDirs = {}
    for key in keys(s:quoteArgs)
        let quoteArgs = s:quoteArgs[key]
        for rep in get(quoteDirsConf, key, [])
            let quoteDirs[rep] = quoteArgs
        endfor
    endfor

    let args = {
                \ 'delimiter': s:quoteEscape(a:delimiter),
                \ 'quoteDirs': quoteDirs
                \ }
    let genFuncs = {
                \ 'C': function('targets#sources#quotes#C'),
                \ 'N': function('targets#sources#quotes#N'),
                \ 'L': function('targets#sources#quotes#L'),
                \ }
    let modFuncs = {
                \ 'i': function('targets#modify#drop'),
                \ 'a': function('targets#modify#keep'),
                \ 'I': function('targets#modify#shrink'),
                \ 'A': function('targets#modify#expand'),
                \ }
    return targets#factory#new(a:delimiter, args, genFuncs, modFuncs)
endfunction

function! targets#sources#quotes#C(gen, first)
    if !a:first
        return targets#target#withError('only one current quote')
    endif

    let dir = s:quoteDir(a:gen.args.quoteDirs, a:gen.args.delimiter)[0]
    return targets#util#select(a:gen.args.delimiter, a:gen.args.delimiter, dir)
endfunction

function! targets#sources#quotes#N(gen, first)
    if !exists('a:gen.state.rate')
        let [_, a:gen.state.rate, _, skipR, _] = s:quoteDir(a:gen.args.quoteDirs, a:gen.args.delimiter)
        let cnt = a:gen.state.rate - skipR " skip initially once
        " echom 'skip'
    else
        let cnt = a:gen.state.rate " then go by rate
        " echom 'no skip'
    endif

    if targets#util#search(a:gen.args.delimiter, 'W', cnt) > 0
        return targets#target#withError('QN')
    endif

    let target = targets#util#select(a:gen.args.delimiter, a:gen.args.delimiter, '>')
    call target.cursorS() " keep going from left end TODO: is this call needed?
    return target
endfunction

function! targets#sources#quotes#L(gen, first)
    if !exists('a:gen.state.rate')
        let [_, a:gen.state.rate, skipL, _, _] = s:quoteDir(a:gen.args.quoteDirs, a:gen.args.delimiter)
        let cnt = a:gen.state.rate - skipL " skip initially once
        " echom 'skip'
    else
        let cnt = a:gen.state.rate " then go by rate
        " echom 'no skip'
    endif

    if targets#util#search(a:gen.args.delimiter, 'bW', cnt) > 0
        return targets#target#withError('QL')
    endif

    let target = targets#util#select(a:gen.args.delimiter, a:gen.args.delimiter, '<')
    call target.cursorE() " keep going from right end TODO: is this call needed?
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
