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
" TODO: remove duplicated factory fields and use factory itself?
" or do a bit of this setup work "outside"?
function! targets#factory#dictnew(oldpos, which) dict
    let gen = {
                \ 'factory': self,
                \ 'oldpos':  a:oldpos,
                \ 'which':   a:which,
                \
                \ 'args':     self.args,
                \ 'nexti':    self.genFuncs[a:which],
                \ 'modFuncs': self.modFuncs,
                \
                \ 'next':   function('targets#generator#next'),
                \ 'nextN':  function('targets#generator#nextN'),
                \ 'target': function('targets#generator#target')
                \ }

    " add args as top level fields of gen
    for key in keys(self.args)
        if has_key(gen, key)
            " TODO: use more obscure internal keys to avoid collisions?
            echom 'duplicate gen key: ' . key
        else
            let Value = self.args[key]
            let gen[key] = Value
        endif
    endfor

    return gen
endfunction

