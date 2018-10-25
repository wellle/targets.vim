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
    " places
    let g:targets_nl = get(g:, 'targets_nl', get(g:, 'targets_nlNL', 'nl')[0:1]) " legacy fallback
    let aiAI         = get(g:, 'targets_aiAI', 'aiAI')
    let [s:a, s:i, s:A, s:I] = split(aiAI, '\zs')
    let [s:n, s:l]           = split(g:targets_nl, '\zs')

    if v:version >= 704 || (v:version == 703 && has('patch338'))
        " if possible, create only a few expression mappings to speed up loading times
        silent! execute 'omap <expr> <unique> ' . s:i . " targets#e('i', '" . s:i . "')"
        silent! execute 'omap <expr> <unique> ' . s:a . " targets#e('a', '" . s:a . "')"
        silent! execute 'omap <expr> <unique> ' . s:I . " targets#e('I', '" . s:I . "')"
        silent! execute 'omap <expr> <unique> ' . s:A . " targets#e('A', '" . s:A . "')"

        silent! execute 'xmap <expr> <unique> ' . s:i . " targets#e('i', '" . s:i . "')"
        silent! execute 'xmap <expr> <unique> ' . s:a . " targets#e('a', '" . s:a . "')"
        silent! execute 'xmap <expr> <unique> ' . s:I . " targets#e('I', '" . s:I . "')"
        silent! execute 'xmap <expr> <unique> ' . s:A . " targets#e('A', '" . s:A . "')"

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

call s:addAllMappings()

let &cpoptions = s:save_cpoptions
unlet s:save_cpoptions
