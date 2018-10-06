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
