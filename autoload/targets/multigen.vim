function! targets#multigen#new(context, lastRawTarget, rangeScores)
    return {
                \ 'gens':          [],
                \ 'context':       a:context,
                \ 'lastRawTarget': a:lastRawTarget,
                \ 'rangeScores':   a:rangeScores,
                \
                \ 'add':    function('targets#multigen#add'),
                \ 'next':   function('targets#multigen#next'),
                \ 'nextN':  function('targets#generator#nextN'),
                \ 'target': function('targets#generator#target')
                \ }
endfunction

function! targets#multigen#add(factories, ...) dict
    let whichs = a:000
    for factory in a:factories
        for which in whichs
            call add(self.gens, factory.new(self.context.oldpos, which))
        endfor
    endfor
endfunction

function! targets#multigen#next(first) dict
    if a:first
        for gen in self.gens
            let first = self.context.newSelection || self.lastRawTarget.gen.factory.trigger != gen.factory.trigger
            call gen.next(first)
        endfor
    else
        call self.currentTarget.gen.next(0) " fill up where we used the last target from
    endif

    let targets = []
    for gen in self.gens
        call add(targets, gen.target())
    endfor

    while 1
        let [target, idx] = s:bestTarget(targets, self.context, self.rangeScores, 'multigen')
        if target.state().isInvalid() " best is invalid -> done
            let self.currentTarget = target
            return self.currentTarget
        endif

        " TODO: can we merge current target and last raw target to avoid this
        " sort of duplication?
        if exists('self.currentTarget')
            if self.currentTarget.equal(target)
                " current target is the same as last one, skip it and try the next one
                let targets[idx] = target.gen.next(0)
                continue
            endif
        elseif !self.context.newSelection && self.lastRawTarget.equal(target)
            " current target is the same as continued one, skip it and try the next one
            " NOTE: this can happen if a multi contains two generators which
            " may create the same target. in that case growing might break
            " without this check
            let targets[idx] = target.gen.next(0)
            continue
        endif

        let self.currentTarget = target
        return self.currentTarget
    endwhile
endfunction

" select best of given targets according to s:rangeScores
" detects for each given target what range type it has, depending on the
" relative positions of the start and end of the target relative to the cursor
" position and the currently visible lines

" The possibly relative positions are:
"   c - on cursor position
"   l - left of cursor in current line
"   r - right of cursor in current line
"   a - above cursor on screen
"   b - below cursor on screen
"   A - above cursor off screen
"   B - below cursor off screen

" All possibly ranges are listed below, denoted by two characters: one for the
" relative start and for the relative end position each of the target. For
" example, `lr` means "from left of cursor to right of cursor in cursor line".

" Next to each range type is a pictogram of an example. They are made of these
" symbols:
"    .  - current cursor position
"   ( ) - start and end of target
"    /  - line break before and after cursor line
"    |  - screen edge between hidden and visible lines

" ranges on cursor:
"   cr   |  /  () /  |   starting on cursor, current line
"   cb   |  /  (  /) |   starting on cursor, multiline down, on screen
"   cB   |  /  (  /  |)  starting on cursor, multiline down, partially off screen
"   lc   |  / ()  /  |   ending on cursor, current line
"   ac   | (/  )  /  |   ending on cursor, multiline up, on screen
"   Ac  (|  /  )  /  |   ending on cursor, multiline up, partially off screen

" ranges around cursor:
"   lr   |  / (.) /  |   around cursor, current line
"   lb   |  / (.  /) |   around cursor, multiline down, on screen
"   ar   | (/  .) /  |   around cursor, multiline up, on screen
"   ab   | (/  .  /) |   around cursor, multiline both, on screen
"   lB   |  / (.  /  |)  around cursor, multiline down, partially off screen
"   Ar  (|  /  .) /  |   around cursor, multiline up, partially off screen
"   aB   | (/  .  /  |)  around cursor, multiline both, partially off screen bottom
"   Ab  (|  /  .  /) |   around cursor, multiline both, partially off screen top
"   AB  (|  /  .  /  |)  around cursor, multiline both, partially off screen both

" ranges after (right of/below) cursor
"   rr   |  /  .()/  |   after cursor, current line
"   rb   |  /  .( /) |   after cursor, multiline, on screen
"   rB   |  /  .( /  |)  after cursor, multiline, partially off screen
"   bb   |  /  .  /()|   after cursor below, on screen
"   bB   |  /  .  /( |)  after cursor below, partially off screen
"   BB   |  /  .  /  |() after cursor below, off screen

" ranges before (left of/above) cursor
"   ll   |  /().  /  |   before cursor, current line
"   al   | (/ ).  /  |   before cursor, multiline, on screen
"   Al  (|  / ).  /  |   before cursor, multiline, partially off screen
"   aa   |()/  .  /  |   before cursor above, on screen
"   Aa  (| )/  .  /  |   before cursor above, partially off screen
"   AA ()|  /  .  /  |   before cursor above, off screen

"     A  a  l r  b  B  relative positions
"      └───────────┘   visible screen
"         └─────┘      current line

" returns best target (and its index) according to range score and distance to cursor
function! s:bestTarget(targets, context, rangeScores, message)
    let [bestScore, minLines, minChars] = [0, 1/0, 1/0] " 1/0 = maxint

    let cnt = len(a:targets)
    for idx in range(cnt)
        let target = a:targets[idx]
        let [range, lines, chars] = target.range(a:context)
        let score = get(a:rangeScores, range)

        " if target.state().isValid()
        "     echom target.string()
        "     echom 'score ' . score . ' lines ' . lines . ' chars ' . chars
        " endif

        if (score > bestScore) ||
                    \ (score == bestScore && lines < minLines) ||
                    \ (score == bestScore && lines == minLines && chars < minChars)
            let [bestScore, minLines, minChars, best, bestIdx] = [score, lines, chars, target, idx]
        endif
    endfor

    if exists('best')
        " echom 'best ' . best.string()
        " echom 'score ' . bestScore . ' lines ' . minLines . ' chars ' . minChars
        return [best, bestIdx]
    endif

    return [targets#target#withError(a:message), -1]
endfunction

