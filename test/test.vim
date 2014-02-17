" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license
" Updated: 2014-02-17
" Version: 0.0.2

set runtimepath+=../
set softtabstop=16 expandtab
source ../plugin/targets.vim

function! s:execute(operation, motions)
    if a:operation == 'c'
        execute "normal " . a:operation . a:motions . "\<C-R>\"\<Esc>v`[r_"
    else
        execute "normal " . a:operation . a:motions
    endif
    if a:operation == 'y'
        execute "normal A\<Tab>'\<C-R>\"'"
    endif
    execute "normal I" . a:operation . a:motions . "\<Tab>\<Esc>"
endfunction

edit test1.in
normal gg

for delset in [
            \ [ '(', ')', 'b' ],
            \ [ '{', '}', 'B' ],
            \ [ '[', ']', 'r' ],
            \ [ '<', '>', 'a' ]
            \ ]
    normal "lyy

    for op in [ 'c', 'd', 'y' ]
        for cnt in [ '', '1', '2' ]
            for nl in [ '', 'n', 'l' ]
                for iaIA in [ 'i', 'a', 'I', 'A' ]
                    for del in delset
                        execute "normal \"lpfx"
                        call s:execute(op, cnt . iaIA . nl . del)
                    endfor
                endfor
            endfor
        endfor
    endfor

    normal +
endfor

normal +

for del in [ "'", '"', '`' ]
    normal "lyy

    for op in [ 'c', 'd', 'y' ]
        for cnt in [ '', '1', '2' ]
            for nlNL in [ '', 'n', 'l', 'N', 'L' ]
                for iaI in [ 'i', 'a', 'I' ]
                    execute "normal \"lpfx"
                    call s:execute(op, cnt . iaI . nlNL . del)
                endfor
            endfor
        endfor
    endfor

    normal +
endfor

normal +

for del in [ ',', '.', ';', ':', '+', '-', '~', '_', '*', '/', '|', '\' ]
    normal "lyy

    for op in [ 'c', 'd', 'y' ]
        for cnt in [ '', '1', '2' ]
            for nlNL in [ '', 'n', 'l', 'N', 'L' ]
                for iaIA in [ 'i', 'a', 'I', 'A' ]
                    execute "normal \"lpfx"
                    call s:execute(op, cnt . iaIA . nlNL . del)
                endfor
            endfor
        endfor
    endfor

    normal +
endfor

write! test1.out
quit!
