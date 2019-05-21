function! targets#multigen#new(context, lastRawTarget)
    return {
                \ 'gens':          [],
                \ 'context':       a:context,
                \ 'lastRawTarget': a:lastRawTarget,
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
            let gen = factory.new(self.context.oldpos, which)
            if gen != {}
                call add(self.gens, gen)
            endif
        endfor
    endfor
endfunction

let s:gracious = get(g:, 'targets_gracious', 0)

function! targets#multigen#next(first) dict
    if a:first
        for gen in self.gens
            call gen.next(1)
        endfor
    else
        call self.currentTarget.gen.next(0) " fill up where we used the last target from
    endif

    let targets = []
    for gen in self.gens
        call add(targets, gen.target())
    endfor

    while 1
        let [target, idx] = s:bestTarget(targets, self.context, 'multigen')
        if target.state().isInvalid() " best is invalid -> done
            let gracious = 1
            " keep last good target if gracious is enabled
            if !exists('self.currentTarget') || !s:gracious
                let self.currentTarget = target
            endif
            return [self.currentTarget, 0]
        endif

        " if two generators produce the same target, skip it
        " also used for growing in some cases
        if self.lastRawTarget.equal(target)
            let targets[idx] = target.gen.next(0)
            continue
        endif

        let self.currentTarget = target
        return [self.currentTarget, 1]
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
function! s:bestTarget(targets, context, message)
    if len(a:targets) == 1
        return [a:targets[0], 0]
    endif

    let [bestScore, minLines, minChars] = [0, 1/0, 1/0] " 1/0 = maxint

    let cnt = len(a:targets)
    for idx in range(cnt)
        let target = a:targets[idx]
        let [range, lines, chars] = target.range(a:context)
        let score = s:rangeScore(range)

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

function! s:rangeScore(range)
    if !exists('s:rangeScores')
        let s:rangeScores = {}
        let ranges = split(get(g:, 'targets_seekRanges',
                    \ 'cc cr cb cB lc ac Ac lr rr ll lb ar ab lB Ar aB Ab AB rb al rB Al bb aa bB Aa BB AA'
                    \ ))
        let rangesN = len(ranges)
        for i in range(rangesN)
            let s:rangeScores[ranges[i]] = rangesN - i
        endfor
    endif
    return get(s:rangeScores, a:range, -1)
endfunction

