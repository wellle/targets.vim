" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license

if exists("g:loaded_targets") || &cp || v:version < 700
    finish
endif
let g:loaded_targets = '0.5.0' " version number
let s:save_cpoptions = &cpoptions
set cpo&vim

function! s:addAllMappings()
    " this is somewhat ugly, but we still need these nl values inside of the
    " expression mapping and don't want to have this legacy fallback in two
    " places. similarly we reuse g:targets_aiAI in the health check
    let g:targets_nl   = s:getKeysAsList(get(g:, 'targets_nl', get(g:, 'targets_nlNL', 'nl')[0:1])) " legacy fallback
    let g:targets_aiAI = s:getKeysAsList(get(g:, 'targets_aiAI', 'aiAI'))
    let mapped_aiAI    = s:getKeysAsList(get(g:, 'targets_mapped_aiAI', g:targets_aiAI))
    let [s:n, s:l]               = g:targets_nl
    let [s:a,  s:i,  s:A,  s:I]  = g:targets_aiAI
    let [s:ma, s:mi, s:mA, s:mI] = mapped_aiAI

    " if possible, create only a few expression mappings to speed up loading times
    if v:version >= 704 || (v:version == 703 && has('patch338'))
        for [modifier, map_lhs, map_rhs] in [
                    \ ['i', s:i, s:mi],
                    \ ['a', s:a, s:ma],
                    \ ['I', s:I, s:mI],
                    \ ['A', s:A, s:mA]]
            " See https://github.com/wellle/targets.vim/pull/242#issuecomment-557931274
            if map_lhs != '' && map_lhs != ' '
                silent! execute printf("omap <expr> <unique> %s targets#e('o', '%s', '%s')", map_lhs, modifier, map_rhs)
                silent! execute printf("xmap <expr> <unique> %s targets#e('o', '%s', '%s')", map_lhs, modifier, map_rhs)
            endif
        endfor

        " #209: The above mappings don't use <silent> for better visual
        " feedback on `!ip` (when we pass back control to Vim). To be silent
        " when calling internal targest functions, we use this special mapping
        " which does use <silent>. It should not lead to conflicts because (
        " is not a valid register.
        onoremap <silent> @(targets) :<C-U>call targets#do()<CR>
        xnoremap <silent> @(targets) :<C-U>call targets#do()<CR>

    else
        " otherwise create individual mappings #117
        " NOTE: for old versions only these legacy settings are used
        " the more flexible targets#mappings only work with the expression
        " mappings above (from Vim version 7.3.338 on)
        call targets#legacy#addMappings(s:a, s:i, s:A, s:I, s:n, s:l)
    endif
endfunction

function! s:getKeysAsList(keys)
    " if it's already an array, no need to split it.
    if type(a:keys) == type([])
        return a:keys
    endif
    " otherwise, it's a string and will be split by char.
    return split(a:keys, '\zs')
endfunction

call s:addAllMappings()

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
