" returns a factory to create generators
" TODO: source needed? (for logging maybe)
function! targets#factory#init(source, factory)
    if type(a:factory) != type({})
        return "must return dictionary"
    endif

    " required
    if !has_key(a:factory, 'genFuncs')
        return "factory missing 'genFuncs'"
    endif

    " optional
    if !has_key(a:factory, 'modFuncs')
        let a:factory['modFuncs'] = {}
    endif

    if !has_key(a:factory, 'args')
        let a:factory['args'] = {}
    endif

    " internal
    let a:factory['new'] = function('targets#factory#new')

    return ''
endfunction

" returns a target generator
" values to be used in genFunc:
" args: forwarded from targets#factory#init (optional)
" state: a fresh empty dictionary per generator (which usually gets created
" per invocation), can be used to remember values between multiple genFunc
" invocations
function! targets#factory#new(oldpos, which) dict
    let GenFunc = get(self.genFuncs, a:which, 0)
    if GenFunc == 0
        " TODO: include source
        echom "factory missing genFunc for '" . a:which . "'"
        return {}
    endif

    " TODO: extract targets#generator#new() to have this defined in the proper
    " place?
    return {
                \ 'args':     self.args,
                \ 'state':    {},
                \
                \ 'oldpos':   a:oldpos,
                \ 'which':    a:which,
                \ 'factory':  self,
                \ 'genFunc':  GenFunc,
                \
                \ 'next':   function('targets#generator#next'),
                \ 'nextN':  function('targets#generator#nextN'),
                \ 'target': function('targets#generator#target')
                \ }
endfunction

