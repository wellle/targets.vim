" returns a factory to create generators
" TODO: can we drop trigger and compare factories differently?
function! targets#factory#new(trigger, args, genFuncs, modFuncs)
    return {
                \ 'trigger':  a:trigger,
                \ 'args':     a:args,
                \ 'genFuncs': a:genFuncs,
                \ 'modFuncs': a:modFuncs,
                \
                \ 'new': function('targets#factory#dictnew'),
                \ }
endfunction

" returns a target generator
" values to be used in genFunc:
" args: forwarded from targets#factory#new
" state: a fresh empty dictionary per generator (which usually gets created
" per invocation), can be used to remember values between multiple genFunc
" invocations
function! targets#factory#dictnew(oldpos, which) dict
    return {
                \ 'args':     self.args,
                \ 'state':    {},
                \
                \ 'oldpos':   a:oldpos,
                \ 'which':    a:which,
                \ 'factory':  self,
                \ 'genFunc':  self.genFuncs[a:which],
                \
                \ 'next':   function('targets#generator#next'),
                \ 'nextN':  function('targets#generator#nextN'),
                \ 'target': function('targets#generator#target')
                \ }
endfunction

