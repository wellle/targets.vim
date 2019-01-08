" targets.vim Provides additional text objects
" Author:  Christian Wellenbrock <christian.wellenbrock@gmail.com>
" License: MIT license

set runtimepath+=../
set softtabstop=16 expandtab
source ../plugin/targets.vim

" tests should pass with this setting too
" set selection=exclusive

function! s:execute(operation, motions)
    if a:operation == 'c'
        execute "normal" a:operation . a:motions . "_"
    elseif a:operation == 'v'
        execute "normal" a:operation . a:motions
        normal r_
    else
        execute "normal" a:operation . a:motions
    endif
    if a:operation == 'y'
        execute "normal A\<Tab>'\<C-R>\"'"
    endif
    execute "normal I" . a:operation . a:motions . "\<Tab>\<Esc>"
endfunction

function! s:testBasic()
    edit test1.in
    normal gg0

    for delset in [
                \ [ '(', ')', 'b' ],
                \ [ '{', '}', 'B' ],
                \ [ '[', ']' ],
                \ [ '<', '>' ],
                \ [ 't' ]
                \ ]
        normal "lyy

        for op in [ 'c', 'd', 'y', 'v' ]
            for cnt in [ '', '1', '2' ]
                for ln in [ 'l', '', 'n' ]
                    for iaIA in [ 'I', 'i', 'a', 'A' ]
                        for del in delset
                            execute "normal \"lpfx"
                            call s:execute(op, cnt . iaIA . ln . del)
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

        for op in [ 'c', 'd', 'y', 'v' ]
            for cnt in [ '', '1', '2' ]
                for ln in [ 'l', '', 'n' ]
                    " this is not supported and somehow gets handled
                    " unexpectedly in these tests, works fine in practice
                    " though (nothing happens)
                    if ln == '' && cnt == '2'
                        continue
                    endif

                    for iaIA in [ 'I', 'i', 'a', 'A' ]
                        execute "normal \"lpfx"
                        call s:execute(op, cnt . iaIA . ln . del)
                    endfor
                endfor
            endfor
        endfor

        normal +
    endfor

    normal +

    for del in [ ',', '.', ';', ':', '+', '-', '=', '~', '_', '*', '#', '/', '|', '\', '&', '$' ]
        normal "lyy

        for op in [ 'c', 'd', 'y', 'v' ]
            for cnt in [ '', '1', '2' ]
                for ln in [ 'l', '', 'n' ]
                    " this is not supported and somehow gets handled
                    " unexpectedly in these tests, works fine in practice
                    " though (nothing happens)
                    if ln == '' && cnt == '2'
                        continue
                    endif

                    for iaIA in [ 'I', 'i', 'a', 'A' ]
                        execute "normal \"lpfx"
                        call s:execute(op, cnt . iaIA . ln . del)
                    endfor
                endfor
            endfor
        endfor

        normal +
    endfor

    normal +

    normal "lyy

    for op in [ 'c', 'd', 'y', 'v' ]
        for cnt in [ '', '1', '2' ]
            for ln in [ 'l', '', 'n' ]
                for iaIA in [ 'I', 'i', 'a', 'A' ]
                    execute "normal \"lpfx"
                    call s:execute(op, cnt . iaIA . ln . 'a')
                endfor
            endfor
        endfor
    endfor

    write! test1.out
endfunction

function! s:testMultiline()
    edit! test2.in
    normal gg0

    execute "normal /comment 1\<CR>"
    set autoindent
    execute "normal cin{foo1\<Esc>''A bar1"
    set autoindent&

    execute "normal /comment 2\<CR>"
    execute "normal din{''A bar2"

    execute "normal /comment 3\<CR>"
    execute "normal cin;foo3\<Esc>''A bar3"

    execute "normal /comment 4\<CR>"
    execute "normal cin`foo4\<Esc>''A bar4"

    execute "normal /comment 5\<CR>"
    execute "normal cI{foo5\<Esc>''A bar5"

    write! test2.out
endfunction

function s:testSeeking()
    edit! test3.in
    normal gg0

    for c in split('PQ', '\zs')
        execute "normal /"   . c . "\<CR>"
        execute "normal cia" . c . "\<Esc>"
    endfor

    for c in split('ABCDEFGHI', '\zs')
        execute "normal /"   . c . "\<CR>"
        execute "normal ci)" . c . "\<Esc>"
    endfor

    for c in split('JKLMNO', '\zs')
        execute "normal /"   . c . "\<CR>"
        execute "normal ci'" . c . "\<Esc>"
    endfor

    write! test3.out
endfunction

function s:testVisual()
    edit! test4.in
    normal gg0

    for delset in [
                \ [ '(', ')', 'b' ],
                \ [ '{', '}', 'B' ],
                \ [ '[', ']' ],
                \ [ '<', '>' ],
                \ [ 't' ]
                \ ]
        normal "lyy

        for ia in [ 'i', 'a' ]
            for del in delset
                normal "lpfx
                execute "normal v" . ia . del . ia . del . "r_"
            endfor
        endfor

        normal +
    endfor

    execute "normal /X\<CR>"
    execute "normal VjIbc.\<Esc>"

    execute "normal /Y\<CR>"
    execute "normal \<C-V>jIbc.\<Esc>"

    write! test4.out
endfunction

function s:testModifiers()
    edit! test5.in
    normal gg0

    normal fxvItr_

    write! test5.out
endfunction

function s:testEmpty()
    edit! test6.in
    normal gg0

    normal ci"foo

    normal +

    normal ci(foo

    normal +

    normal ci,foo

    write! test6.out
endfunction

function s:testQuotes()
    edit! test7.in
    normal gg0

    for p in split("010 001 201 100 102 012 111 210 212 101 011 211 110 112 000 002 200 202")
        execute "normal /" . p . "\<CR>"
        normal "pyip}

        for cnt in [ '', '1', '2' ]
            for ln in [ 'l', '', 'n' ]
                " this is not supported and somehow gets handled
                " unexpectedly in these tests, works fine in practice
                " though (nothing happens)
                if ln == '' && cnt == '2'
                    continue
                endif

                for iaIA in [ 'I', 'i', 'a', 'A' ]
                    execute "normal \"pPnw"
                    let command = "v" . cnt . iaIA . ln . "'"
                    execute "normal" command . "r_A" command . "\<Esc>}"
                endfor
            endfor
        endfor
    endfor

    write! test7.out
endfunction

function s:testReselect()
    edit! test8.in
    normal gg0

    " select a word, then try to select a block, which fails
    " should still be selecting word, so the first word should be changed
    normal viw
    normal ab
    normal cfoo

    write! test8.out
endfunction

function s:testGrow()
    edit! test9.in
    normal gg0

    " from x, select an argument, grow it
    normal fxvaaaar_

    normal +

    " from x, select last argument, grow it
    normal fxvalaaar_

    normal +

    " from x, select inner argument, select an argument (shouldn't grow)
    normal fxviaaar_

    normal +

    " from x, select inner argument, select secound outer argument (shouldn't grow extra)
    normal fxvia2aar_

    normal +

    " from x, select argument, grow, select next (should shrink)
    normal fxvaaaaanar_

    normal +

    " from x, select argument, grow, switch to start, select last (should shrink)
    normal fxvaaaaoalar_

    normal +

    " grow between characterwise and linewise selections
    execute "normal /X\<CR>"
    normal vibibibibibibr_

    write! test9.out
endfunction

function s:testMotionForce()
    edit! test10.in

    execute "normal /X1\<CR>"
    execute "normal di-"

    execute "normal /X2\<CR>"
    execute "normal dvi-"

    execute "normal /X3\<CR>"
    execute "normal dVi-"

    execute "normal /X4\<CR>"
    execute "normal d\<C-V>i-"

    write! test10.out
endfunction

redir >> testM.out

call s:testBasic()
call s:testMultiline()
call s:testSeeking()
call s:testVisual()
call s:testModifiers()
call s:testEmpty()
call s:testQuotes()
call s:testReselect()
call s:testGrow()
call s:testMotionForce()

redir END
" remove blank messages and trailing whitespace
edit! testM.out
v/./d
%s/\s\+$
write! testM.out

quit!
