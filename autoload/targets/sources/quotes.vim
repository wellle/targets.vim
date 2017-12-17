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
        let args = s:quoteArgs[key]
        for rep in get(quoteDirsConf, key, [])
            let quoteDirs[rep] = args
        endfor
    endfor

    let args = {
                \ 'delimiter': s:quoteEscape(a:delimiter),
                \ 'quoteDirs': quoteDirs,
                \
                \ 'quoteDir': function('s:quoteDir'),
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

function! targets#sources#quotes#C(first) dict
    if !a:first
        return targets#target#withError('only one current quote')
    endif

    let dir = self.quoteDir(self.delimiter)[0]
    let self.currentTarget = targets#util#select(self.delimiter, self.delimiter, dir, self)
    return self.currentTarget
endfunction

function! targets#sources#quotes#N(first) dict
    if !exists('self.rate')
        " do outside somehow? if so remember to reset pos before
        " TODO: do on init somehow? that way we don't need to do it three
        " times for seeking
        let [_, self.rate, _, skipR, _] = self.quoteDir(self.delimiter)
        let cnt = self.rate - skipR " skip initially once
        " echom 'skip'
    else
        let cnt = self.rate " then go by rate
        " echom 'no skip'
    endif

    if targets#util#search(self.delimiter, 'W', cnt) > 0
        return targets#target#withError('QN')
    endif

    let target = targets#util#select(self.delimiter, self.delimiter, '>', self)
    call target.cursorS() " keep going from left end TODO: is this call needed?
    return target
endfunction

function! targets#sources#quotes#L(first) dict
    if !exists('self.rate')
        let [_, self.rate, skipL, _, _] = self.quoteDir(self.delimiter)
        let cnt = self.rate - skipL " skip initially once
        " echom 'skip'
    else
        let cnt = self.rate " then go by rate
        " echom 'no skip'
    endif

    if targets#util#search(self.delimiter, 'bW', cnt) > 0
        return targets#target#withError('QL')
    endif

    let target = targets#util#select(self.delimiter, self.delimiter, '<', self)
    call target.cursorE() " keep going from right end TODO: is this call needed?
    return target
endfunction

" returns [dir, rate, skipL, skipR, error]
function! s:quoteDir(delimiter) dict
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
    let [dir, rate, skipL, skipR, error] = get(self.quoteDirs, key, defaultValues)
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
