" maps source to factory constructor, default sources get registered below
" more can be added (before first use) via targets#sources#register()
let s:sources = {}

function! targets#sources#register(source, newFactoryFunc)
    if has_key(s:sources, a:source)
        echom 'targets.vim failed to register source ' . a:source . ' (already exists)'
    else
        let s:sources[a:source] = a:newFactoryFunc
        " echom 'registered source: ' . a:source
    endif
endfunction

function! s:registerSources()
    " register default sources
    call targets#sources#register('pair',      function('targets#sources#pair#new'))
    call targets#sources#register('quote',     function('targets#sources#quote#new'))
    call targets#sources#register('separator', function('targets#sources#separator#new'))
    call targets#sources#register('argument',  function('targets#sources#argument#new'))
    call targets#sources#register('tag',       function('targets#sources#tag#new'))

    " avoid message "No matching autocommands" in some cases
    augroup targets#sources#silent
        autocmd!
        autocmd User targets#sources silent
    augroup END

    " allow targets plugins to register their sources
    doautocmd User targets#sources
endfunction

function! targets#sources#newFactories(trigger)
    let factories = []
    let sources = targets#mappings#get(a:trigger)
    for source in keys(sources)
        for args in sources[source]
            if !has_key(s:sources, source)
                echom "targets.vim source '" . source . "' not registered"
                continue
            endif

            let factory = call(s:sources[source], [args])
            let err = targets#factory#init(source, factory)
            if err != ''
                echom "targets.vim source '" . source . "': " . err
                continue
            endif

            call add(factories, factory)
        endfor
    endfor
    return factories
endfunction

call s:registerSources()
