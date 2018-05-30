function! targets#context#new(mapmode, trigger, newSelection, visualTarget)
    return {
                \ 'mapmode':      a:mapmode,
                \ 'trigger':      a:trigger,
                \ 'newSelection': a:newSelection,
                \ 'visualTarget': a:visualTarget,
                \
                \ 'oldpos':  getpos('.'),
                \ 'minline': line('w0'),
                \ 'maxline': line('w$'),
                \ 'withOldpos': function('targets#context#withOldpos'),
                \ }
endfunction

function! targets#context#withOldpos(oldpos) dict
    let context = deepcopy(self)
    let context.oldpos = a:oldpos
    return context
endfunction

