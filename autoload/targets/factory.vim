" the factory dict passed into #init can have these keys:
" args:     optional, passed to each generator call
" genFuncs: required, map 'c', 'n', 'l' to generator
"   functions (current, next, last respectively)
" modFuncs: optional, map 'i', 'a', 'I', 'A' to modify
"   functions

" returns a factory to create generators
function! targets#factory#init(source, factory)
    if type(a:factory) != type({})
        return "must return dictionary"
    endif

    " required
    if !has_key(a:factory, 'genFuncs')
        return "missing 'genFuncs'"
    endif

    " optional
    if !has_key(a:factory, 'modFuncs')
        let a:factory['modFuncs'] = {}
    endif

    if !has_key(a:factory, 'args')
        let a:factory['args'] = {}
    endif

    " internal
    let a:factory['source'] = a:source
    let a:factory['new']    = function('targets#factory#new')

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
        " NOTE: we could drop this message and consider individual gen funcs
        " optional. but for seeking to work we need all three, so all of them
        " are required for now
        echom "targets.vim source '" . self.source . "': no genFunc for '" . a:which . "'"
        return {}
    endif

    return targets#generator#new(GenFunc, self.modFuncs, self.source, self.args, a:oldpos, a:which)
endfunction

