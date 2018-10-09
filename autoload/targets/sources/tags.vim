" tags are implemented as special pairs
" special args must not be modified/escaped
function! targets#sources#tags#new(args)
    return {
                \ 'args': {
                \     'opening': '<\a',
                \     'closing': '</\a\zs',
                \     'trigger': 't',
                \ },
                \ 'genFuncs': {
                \     'c': function('targets#sources#pairs#current'),
                \     'n': function('targets#sources#pairs#next'),
                \     'l': function('targets#sources#pairs#last'),
                \ },
                \ 'modFuncs': {
                \     'i': [function('targets#modify#innert'), function('targets#modify#drop')],
                \     'a': [function('targets#modify#keep')],
                \     'I': [function('targets#modify#innert'), function('targets#modify#shrink')],
                \     'A': [function('targets#modify#expand')],
                \ }}
endfunction

