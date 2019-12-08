function! health#targets#check() abort
    let conflicts = 0

    for trigger in targets#mappings#list()
        for ai in g:targets_aiAI
            let conflicts += s:check(trigger, ai . trigger)
            for nl in g:targets_nl
                let conflicts += s:check(trigger, ai . nl . trigger)
            endfor
        endfor
    endfor

    if conflicts == 0
        call health#report_ok('No conflicting mappings found')
    endif
endfunction

function! s:check(trigger, map)
    for mode in ['x', 'o']
        let arg = maparg(a:map, mode)
        if arg == ''
            continue
        endif

        call health#report_warn("Conflicting mapping found:\n"
                    \ . a:map . ' → ' . arg . "\n"
                    \ . a:trigger . " → " . string(targets#mappings#get(a:trigger))
                    \ )
        " no need to warn again for the other mode
        return 1
    endfor
    return 0
endfunction
