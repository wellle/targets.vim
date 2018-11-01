## Internals

In order to understand how plugins can add new targets sources, lets first have
a look at how targets.vim works internally.

The basic flow works like this:
- Each source can be used to create a factory for a given set of args.
- A factory can be used to create generators of different type. Possible types
  are current (target around cursor), next (target after cursor) and last
  (target before cursor). A new generator is usually created per invocation
  (the last generator will be reused if possible, for example for growing and
  skipping)
- A generator can be called multiple times to generate a list of targets. For
  example the generator for current targets should return the smallest targets
  closest to the cursor on the first call, the next bigger one on the next call
  and so on. The generator for next targets should first return the first next
  target (closest to the cursor, but to the right/below of the cursor), the
  next call should return the second closest of that type etc. If no more
  targets are available, because there are no enclosing ones any more, or the
  end of file is reached, a generator can indicate that by returning an error
  (pseudo) target which will be handled accordingly.

For example, lets see what happens when you type `d2inq` to delete in the
second next quote:

- Vim will parse the typed character `d` and remember that as operator func to
  be used later.
- Vim will parse 2 and recognize it as count, accessed by targets.vim later.
- Vim will parse `i` in operator pending mode and find find and execute the
  expression mapping from targets.vim.
- `targets#e()` gets called with a parameter telling it that `i` was typed,
  which we remember as `modifier` for later use. It then continues reading
  characters until the command is complete or when it recognizes that no such
  target is set up. In our case it reads the `n` which is recognized as `which`
  (which is either `c` (current), `n` (next) or `l` (last)). Finally it reads
  `q` which it recognizes as `trigger`.
- targets.vim uses the trigger to look up sources from its internal mappings.
  For trigger `q` it finds a single source `quote` with three sets of
  arguments. It looks up the source `quote` to find a factory constructor and
  uses it to create three quote factories, one for single quotes, one fore
  double quotes and one for backticks. (unless they were already cached by the
  trigger `q`).
- targets.vim takes uses three factories to one generator each. Here we use the
  `which` value of `n` to get three generators, one to find next double quote
  targets, one for next single quote targets and one for next backtick targets.
- targets.vim create a multi generator out of those three generators. Since we
  had a count of 2, this multi gen will be called two times. On the first call
  it calls each internal generator once to get three next quote targets of the
  respective kind. It compares them to pick the best one (according to
  `g:targets_seekRanges`). This would have been the first next quote target,
  but is discarded because we asked for the second. On the second call the
  internal generator which yielded the first best target gets called again, to
  produce the second best of that kind. This one gets compared with the first
  best targets from the other internal generators from earlier, to be declared
  the best of this round, which in turn is our second next best quote target
  we've asked for.
- targets.vim apply the proper modify function, depending on the `modifier`
  value and the source.

While mappings can use multiple sources and multiple args per source to create
any multi targets, most triggers are mapped to a single source with a single
set of args. However, the multi generator approach is still being used for all
of them to support seeking. For example, if type `ci)`, we get a single factory
for `()` pair targets, but we use it to get all three generators for current,
next and last pair. Then we use a multi generator to pick the best available
target. Depending on the seek ranges again, usually this will be the target
around the cursor if available. But if that one doesn't exist, it automatically
switches to the next or last one, depending on which one is deemed better

## Plugins

It's possible to extend targets.vim by adding new sources. Text objects
implemented as targets.vim plugin will automatically gain all the functionality
of the built in ones. Most notably you can use `n` and `l` to select next and
last one, provide counts to pick a specific one, use seeking (`vix` pick
current, next or last), growing (`vixix` is the same as `v2ix` etc.) and
skipping `vinxinx` is the same as `v2inx`).

The basic steps are:
1. Register your new source: Map source name to factory constructor function.
2. Optionally add some default mappings: Map trigger to your source with some
   args.
3. Implement the factory constructor: This declares generator functions (all
   three required) and modify functions (optional).
4. Implement the generator functions: These functions might be called multiple
   times and should yield more and more distant targets on each call.
5. Implement modify functions: These functions take a target and a modifier
   (`i`, `a`, `I` or `A`) and should return the modified target. The ones used
   by targets.vim internally are available for external use. These include
   basic white space handling.

An example source with comments is implemented in
[line-targets.vim][linetargets].  Please have a look at that repository to see
how such an implementation can be organized.

[linetargets]: https://github.com/wellle/line-targets.vim
