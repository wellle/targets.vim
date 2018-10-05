function! targets#settings#rangeScores()
    let rangeScores = {}
    let ranges = split(get(g:, 'targets_seekRanges',
                \ 'cr cb cB lc ac Ac lr rr ll lb ar ab lB Ar aB Ab AB rb al rB Al bb aa bB Aa BB AA'
                \ ))
    let rangesN = len(ranges)
    for i in range(rangesN)
        let rangeScores[ranges[i]] = rangesN - i
    endfor
    return rangeScores
endfunction

function! targets#settings#rangeJumps()
    let rangeJumps = {}
    let ranges = split(get(g:, 'targets_jumpRanges', 'bb bB BB aa Aa AA'))
    for i in range(len(ranges))
        let rangeJumps[ranges[i]] = 1
    endfor
    return rangeJumps
endfunction

" TODO: since we use this not only for multis now, rename this function and s:multis?
function! targets#settings#multis()
    " TODO: document this
    let defaultMultis = {
                \ 'b': { 'pairs':  [{'o':'(', 'c':')'}, {'o':'[', 'c':']'}, {'o':'{', 'c':'}'}], },
                \ 'q': { 'quotes': [{'d':"'"}, {'d':'"'}, {'d':'`'}], },
                \ }

    " we need to assign these like this because Vim 7.3 doesn't seem to like
    " variables as keys in dict definitions like above
    let defaultMultis[g:targets_tagTrigger] = { 'tags': [{}], }
    let defaultMultis[g:targets_argTrigger] = { 'arguments': [{
                \ 'o': get(g:, 'targets_argOpening', '[([]'),
                \ 'c': get(g:, 'targets_argClosing', '[])]'),
                \ 's': get(g:, 'targets_argSeparator', ','),
                \ }], }

    let multis = get(g:, 'targets_multis', defaultMultis)

    for pair in split(g:targets_pairs)
        let config = {'pairs': [{'o':pair[0], 'c':pair[1]}]}
        for trigger in split(pair, '\zs')
            call extend(multis, {trigger: config}, 'keep')
        endfor
    endfor

    for quote in split(g:targets_quotes)
        let config = {'quotes': [{'d':quote[0]}]}
        for trigger in split(quote, '\zs')
            call extend(multis, {trigger: config}, 'keep')
        endfor
    endfor

    for separator in split(g:targets_separators)
        let config = {'separators': [{'d':separator[0]}]}
        for trigger in split(separator, '\zs')
            call extend(multis, {trigger: config}, 'keep')
        endfor
    endfor

    return multis
endfunction
