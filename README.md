## Introduction

**Targets.vim** is a Vim plugin that adds various [text objects][textobjects]
to give you more targets to [operate][operator] on.  It expands on the idea of
simple commands like `di'` (delete inside the single quotes around the cursor)
to give you more opportunities to craft powerful commands that can be
[repeated][repeat] reliably. One major goal is to handle all corner cases
correctly.

## Table of Contents

<details>
<summary>Click here to show.</summary>

<!-- BEGIN-MARKDOWN-TOC -->

* [Installation](#installation)
* [Examples](#examples)
* [Overview](#overview)
	* [Pair Text Objects](#pair-text-objects)
		* [In Pair](#in-pair)
		* [A Pair](#a-pair)
		* [Inside Pair](#inside-pair)
		* [Around Pair](#around-pair)
		* [Next and Last Pair](#next-and-last-pair)
		* [Pair Seek](#pair-seek)
	* [Quote Text Objects](#quote-text-objects)
		* [In Quote](#in-quote)
		* [A Quote](#a-quote)
		* [Inside Quote](#inside-quote)
		* [Around Quote](#around-quote)
		* [Next and Last Quote](#next-and-last-quote)
		* [Quote Seek](#quote-seek)
	* [Separator Text Objects](#separator-text-objects)
		* [In Separator](#in-separator)
		* [A Separator](#a-separator)
		* [Inside Separator](#inside-separator)
		* [Around Separator](#around-separator)
		* [Next and Last Separator](#next-and-last-separator)
		* [Separator Seek](#separator-seek)
	* [Argument Text Objects](#argument-text-objects)
		* [In Argument](#in-argument)
		* [An Argument](#an-argument)
		* [Inside Argument](#inside-argument)
		* [Around Argument](#around-argument)
		* [Next and Last Argument](#next-and-last-argument)
		* [Argument Seek](#argument-seek)
	* [Multi Text Objects](#multi-text-objects)
		* [Any Block](#any-block)
		* [Any Quote](#any-quote)
* [Settings](#settings)
	* [g:targets_aiAI](#gtargets_aiai)
	* [g:targets_mapped_aiAI](#gtargets_mapped_aiai)
	* [g:targets_nl](#gtargets_nl)
	* [g:targets_seekRanges](#gtargets_seekranges)
	* [g:targets_jumpRanges](#gtargets_jumpranges)
	* [g:targets_gracious](#gtargets_gracious)
	* [targets#mappings#extend](#targets#mappings#extend)
* [Notes](#notes)
* [Issues](#issues)
* [Todos](#todos)

</details>

<!-- END-MARKDOWN-TOC -->

## Installation

| Plugin Manager         | Command                                                                       |
|------------------------|-------------------------------------------------------------------------------|
| [NeoBundle][neobundle] | `NeoBundle 'wellle/targets.vim'`                                              |
| [Vundle][vundle]       | `Bundle 'wellle/targets.vim'`                                                 |
| [Vim-plug][vim-plug]   | `Plug 'wellle/targets.vim'`                                                   |
| [Pathogen][pathogen]   | `git clone git://github.com/wellle/targets.vim.git ~/.vim/bundle/targets.vim` |
| [Dein][dein]		     | `call dein#add('wellle/targets.vim')`					                     |

## Examples

The following examples are displayed as three lines each. The top line denotes
cursor positions from where the presented command works. The middle line shows
the contents of the example line that we're working on. The last line shows the
part of the line that the command will operate on.

To change the text in the next pair of parentheses, use the `cin)` command

```
cursor position │    .....................
buffer line     │    This is example text (with a pair of parentheses).
selection       │                          └───────── cin) ─────────┘
```

To delete the item in a comma separated list under the cursor, use `da,`

```
cursor position │                                  .........
buffer line     │    Shopping list: oranges, apples, bananas, tomatoes
selection       │                                  └─ da, ─┘
```

Notice how the selection includes exactly one of the surrounding commas to
leave a proper comma separated list behind.

## Overview

Targets.vim comes with five kinds for text objects:

- Pair text objects
- Quote text objects
- Separator text objects
- Argument text objects
- Tag text objects

Each of those kinds is implemented by a targets source. Third party plugins can
provide additional sources to add even more text objects which behave like the
built in ones. See [plugins][Plugins] for details on how to implement your own
targets source.

### Pair Text Objects

These text objects are similar to the built in text objects such as `i)`.
Supported trigger characters:

- `(` `)` (work on parentheses)
- `{` `}` `B` (work on curly braces)
- `[` `]` (work on square brackets)
- `<` `>` (work on angle brackets)
- `t` (work on tags)

Pair text objects work over multiple lines and support seeking. See below for
details about seeking.

The following examples will use parentheses, but they all work for each listed
trigger character accordingly.

#### In Pair

`i( i) i{ i} iB i[ i] i< i> it`

- Select inside of pair characters.
- This overrides Vim's default text object to allow seeking for the next pair
  in the current line to the right or left when the cursor is not inside a
  pair. This behavior is similar to Vim's seeking behavior of `di'` when not
  inside of quotes, but it works both ways.
- Accepts a count to select multiple blocks.

```
      ............
a ( b ( cccccccc ) d ) e
   │   └── i) ──┘   │
   └───── 2i) ──────┘
```

#### A Pair

`a( a) a{ a} aB a[ a] a< a> at`

- Select a pair including pair characters.
- Overrides Vim's default text object to allow seeking.
- Accepts a count.

```
      ............
a ( b ( cccccccc ) d ) e
  │   └─── a) ───┘   │
  └────── 2a) ───────┘
```

#### Inside Pair

`I( I) I{ I} IB I[ I] I< I> It`

- Select contents of pair characters.
- Like inside of parentheses, but exclude whitespace at both ends. Useful for
  changing contents while preserving spacing.
- Accepts a count.

```
      ............
a ( b ( cccccccc ) d ) e
    │   └─ I) ─┘   │
    └──── 2I) ─────┘
```

#### Around Pair

`A( A) A{ A} AB A[ A] A< A> At`

- Select around pair characters.
- Like a pair, but include whitespace at one side of the pair. Prefers to
  select trailing whitespace, falls back to select leading whitespace.
- Accepts a count.

```
      ............
a ( b ( cccccccc ) d ) e
  │   └─── A) ────┘   │
  └────── 2A) ────────┘
```

#### Next and Last Pair

`in( an( In( An( il( al( Il( Al( ...`

Work directly on distant pairs without moving there separately.

All the above pair text objects can be shifted to the next pair by
including the letter `n`. The command `in)` selects inside of the next
pair. Use the letter `l` instead to work on the previous (last) pair. Uses
a count to skip multiple pairs. Skipping works over multiple lines.

See our [Cheat Sheet][cheatsheet] for two charts summarizing all pair mappings.

#### Pair Seek

If any of the normal pair commands (not containing `n` or `l`) is executed when
the cursor is not positioned inside a pair, it seeks for pairs before or after
the cursor by searching for the appropriate delimiter on the current line. This
is similar to using the explicit version containing `n` or `l`, but in only
seeks on the current line.

### Quote Text Objects

These text objects are similar to the built in text objects such as `i'`.
Supported trigger characters:

- `'`     (work on single quotes)
- `"`     (work on double quotes)
- `` ` `` (work on back ticks)

These quote text objects try to be smarter than the default ones. They count
the quotation marks from the beginning of the line to decide which of these are
the beginning of a quote and which ones are the end.

If you type `ci"` on the `,` in the example below, it will automatically skip
and change `world` instead of changing `,` between `hello` and `world`.

```
buffer │ join("hello", "world")
proper │      └─────┘  └─────┘
false  │            └──┘
```

Quote text objects work over multiple lines and support seeking. See below for
details about seeking.

The following examples will use single quotes, but they all work for each
mentioned separator character accordingly.

#### In Quote

`` i' i" i` ``

- Select inside quote.
- This overrides Vim's default text object to allow seeking in both directions.

```
  ............
a ' bbbbbbbb ' c ' d ' e
   └── i' ──┘
```

#### A Quote

``a' a" a` ``

- Select a quote.
- This overrides Vim's default text object to support seeking.
- Unlike Vim's quote text objects, this incudes no surrounding whitespace.

```
  ............
a ' bbbbbbbb ' c ' d ' e
  └─── a' ───┘
```

#### Inside Quote

``I' I" I` ``

- Select contents of a quote.
- Like inside quote, but exclude whitespace at both ends. Useful for changing
  contents while preserving spacing.

```
  ............
a ' bbbbbbbb ' c ' d ' e
    └─ I' ─┘
```

#### Around Quote

``A' A" A` ``

- Select around a quote.
- Like a quote, but include whitespace in one direction. Prefers to select
  trailing whitespace, falls back to select leading whitespace.

```
  ............
a ' bbbbbbbb ' c ' d ' e
  └─── A' ────┘
```

#### Next and Last Quote

`in' In' An' il' Il' Al' ...`

Work directly on distant quotes without moving there separately.

All the above pair text objects can be shifted to the next quote by
including the letter `n`. The command `in'` selects inside of the next
single quotes. Use the letter `l` instead to work on the previous (last)
quote. Uses a count to skip multiple quotation characters.

See our [Cheat Sheet][cheatsheet] for a chart summarizing all quote mappings.

#### Quote Seek

If any of the normal quote commands (not containing `n` or `l`) is executed
when the cursor is not positioned inside a quote, it seeks for quotes before or
after the cursor by searching for the appropriate delimiter on the current
line. This is similar to using the explicit version containing `n` or `l`.

### Separator Text Objects

These text objects are based on single separator characters like the comma in
one of our examples above. The text between two instances of the separator
character can be operated on with these targets.

Supported separators:

```
, . ; : + - = ~ _ * # / | \ & $
```

Separator text objects work over multiple lines and support seeking.

The following examples will use commas, but they all work for each listed
separator character accordingly.

#### In Separator

`i, i. i; i: i+ i- i= i~ i_ i* i# i/ i| i\ i& i$`

- Select inside separators. Similar to in quote.

```
      ...........
a , b , cccccccc , d , e
       └── i, ──┘
```

#### A Separator

`a, a. a; a: a+ a- a= a~ a_ a* a# a/ a| a\ a& a$`

- Select an item in a list separated by the separator character.
- Includes the leading separator, but excludes the trailing one. This leaves
  a proper list separated by the separator character after deletion. See the
  examples above.

```
      ...........
a , b , cccccccc , d , e
      └─── a, ──┘
```

#### Inside Separator

`I, I. I; I: I+ I- I= I~ I_ I* I# I/ I| I\ I& I$`

- Select contents between separators.
- Like inside separators, but exclude whitespace at both ends. Useful for
  changing contents while preserving spacing.

```
      ...........
a , b , cccccccc , d , e
        └─ I, ─┘
```

#### Around Separator

`A, A. A; A: A+ A- A= A~ A_ A* A# A/ A| A\ A& A$`

- Select around a pair of separators.
- Includes both separators and a surrounding whitespace, similar to `a'` and
  `A(`.

```
      ...........
a , b , cccccccc , d , e
      └─── A, ────┘
```

#### Next and Last Separator

`in, an, In, An, il, al, Il, Al, ...`

Work directly on distant separators without moving there separately.

All the above separator text objects can be shifted to the next separator by
including the letter `n`. The command `in,` selects inside of the next commas.
Use the letter `l` instead to work on the previous (last) separators. Uses the
count to skip multiple separator characters.

See our [Cheat Sheet][cheatsheet] for a chart summarizing all separator mappings.

#### Separator Seek

Like quote seeking. If any of the normal separator commands (not
containing `n` or `l`) is executed when the cursor is not positioned inside a
pair of separators, it seeks for the separator before or after the cursor.
This is similar to using the explicit version containing `n` or `l`.

### Argument Text Objects

These text objects are similar to separator text objects, but are specialized
for arguments surrounded by braces and commas. They also take matching braces
into account to capture only valid arguments.

Argument text objects work over multiple lines and support seeking.

#### In Argument

`ia`

- Select inside arguments. Similar to in quote.
- Accepts a count.

```
      ...........
a , b ( cccccccc , d ) e
       └── ia ──┘
```

#### An Argument

`aa`

- Select an argument in a list of arguments.
- Includes a separator if preset, but excludes surrounding braces. This leaves
  a proper argument list after deletion.
- Accepts a count.

```
      ...........
a , b ( cccccccc , d ) e
        └─── aa ──┘
```

#### Inside Argument

`Ia`

- Select content of an argument.
- Like inside separators, but exclude whitespace at both ends. Useful for
  changing contents while preserving spacing.
- Accepts a count.

```
      ...........
a , b ( cccccccc , d ) e
        └─ Ia ─┘
```

#### Around Argument

`Aa`

- Select around an argument.
- Includes both delimiters and a surrounding whitespace, similar to `a'` and
  `A(`.
- Accepts a count.

```
      ...........
a , b ( cccccccc , d ) e
      └─── Aa ────┘
```

#### Next and Last Argument

`ina ana Ina Ana ila ala Ila Ala`

Work directly on distant arguments without moving there separately.

All the above argument text objects can be shifted to the next argument by
including the letter `n`. The command `ina` selects inside of the next
argument. Use the letter `l` instead to work on the previous (last) argument.
Uses a [count] to skip multiple argument characters. The order is determined by
the nearest surrounding argument delimiter.

See our [Cheat Sheet][cheatsheet] for a chart summarizing all argument mappings.

#### Argument Seek

Like separator seeking. If any of the normal argument commands (not containing
`n` or `l`) is executed when the cursor is not positioned inside an argument,
it seeks for the argument before or after the cursor. This is similar to using
the explicit version containing `n` or `l`.

### Multi Text Objects

Two multi text objects are included in default settings. See the section on
settings below to see how to set up other similar multi text objects or
customize the built in ones.

#### Any Block

`inb anb Inb Anb ilb alb Ilb Alb`

Similar to pair text objects, if you type `dib` within `()` it will delete in
these. If you do the same within `{}` it will delete in those. If you type
`d2inb` it will skip one next pair (any kind) and delete in the one after (any
kind). If you're within `()` nested in `{}`, type `d2ib` to delete in `{}`. All
of the usual seeking, growing and skipping works.

#### Any Quote

`inq anq Inq Anq ilq alq Ilq Alq`

Similar to quote text objects, if you type `diq` within `""` it will delete in
these. If you do the same within `''` it will delete in those. If you type
`d2inq` it will skip one next quote text object (any kind) and delete in the
one after (any kind). If you're within `""` nested in `''`, type `d2iq` to
delete in `''`. All of the usual seeking, growing and skipping works.

## Settings

You can customize the mappings and text objects with the settings described
here.

### g:targets_aiAI

Default:

```vim
let g:targets_aiAI = 'aiAI'
```

Controls the normal mode operator mode maps that get created for In Pair (`i`),
A Pair (`a`), Inside Pair (`I`), and Around Pair (`A`). Required to be either a
string or a list with 4 characters/elements.

Use a space to deactivate a mode. If you want to use multiple keys, for example
`<Space>a` instead of `A`, you must use a list.

In contrast to `g:targets_nl`, special keys must not be escaped with a
backslash. For example, use `"<Space>"`
or `'<Space>'`, **not** `"\<Space>"`. Example for configuring `g:targets_aiAI`:

```vim
let g:targets_aiAI = ['<Space>a', '<Space>i', '<Space>A', '<Space>I']
```

### g:targets_mapped_aiAI

Default:

```vim
let g:targets_mapped_aiAI = g:targets_aiAI
```

If you can't get your g:targets_aiAI settings to work because they conflict
with other mappings you have, you might need to use g:targets_mapped_aiAI. For
example if you want to map `k` to `i` and use `k` as `i` in targets mappings,
you need to NOT map `k` to `i` in operator pending mode, and set
`g:targets_aiAI = 'akAI'` and `g:targets_mapped_aiAI = 'aiAI'`.

Has the same format as `g:targets_aiAI`.

For more details see issue #213 and don't hesitate to comment there or open a
new issue if you need assistance.

### g:targets_nl

Default:

```vim
let g:targets_nl = 'nl'
```

Controls the keys used in maps for seeking next and last text objects. For
example, if you want `n` to always search for the next object and `N` to search
for the last, you could set:

```vim
let g:targets_nl = 'nN'
```

Required to be either a string or a list with 2 characters/elements.

Use a space to deactivate a mode. If you want to use multiple keys, for example
`<Space>n` instead of `n`, you must use a list.

In contrast to `g:targets_aiAI`, special keys must be escaped with a backslash.
For example, use `"\<Space>"`, **not** `"<Space>"` nor `'<Space>'`. Example for
configuring `g:targets_nl`:

```vim
let g:targets_nl = ["\<Space>n", "\<Space>l"]
```

### g:targets_seekRanges

Default:

```vim
let g:targets_seekRanges = 'cc cr cb cB lc ac Ac lr rr ll lb ar ab lB Ar aB Ab AB rb al rB Al bb aa bB Aa BB AA'
```

Defines a priority ordered, space separated list of range types which can be
used to customize seeking behavior.

The default setting generally prefers targets around the cursor, with one
exception: If the target around the cursor is not contained in the current
cursor line, but the next or last target are, then prefer those. Targets
beginning or ending on the cursor are preferred over everything else.

Some other useful example settings:

Prefer multiline targets around cursor over distant targets within cursor line:
```vim
let g:targets_seekRanges = 'cc cr cb cB lc ac Ac lr lb ar ab lB Ar aB Ab AB rr ll rb al rB Al bb aa bB Aa BB AA'
```

Never seek backwards:
```vim
let g:targets_seekRanges = 'cc cr cb cB lc ac Ac lr rr lb ar ab lB Ar aB Ab AB rb rB bb bB BB'
```

Only seek if next/last targets touch current line:
```vim
let g:targets_seekRanges = 'cc cr cb cB lc ac Ac lr rr ll lb ar ab lB Ar aB Ab AB rb rB al Al'
```

Only consider targets fully visible on screen:
```vim
let g:targets_seekRanges = 'cc cr cb cB lc ac Ac lr lb ar ab rr rb bb ll al aa'
```

Only consider targets around cursor:
```vim
let g:targets_seekRanges = 'cc cr cb cB lc ac Ac lr lb ar ab lB Ar aB Ab AB'
```

Only consider targets fully contained in current line:
```vim
let g:targets_seekRanges = 'cc cr cb cB lc ac Ac lr rr ll'
```

If you want to build your own, or are just curious what those cryptic letters
mean, check out the full documentation in our [Cheat Sheet][cheatsheet].

### g:targets_jumpRanges

Default:

```vim
let g:targets_jumpRanges = 'bb bB BB aa Aa AA'
```

Defines an unordered, space separated list of range types which can be used to
customize the jumplist behavior (see documentation on seek ranges). It
controls whether or not to add the cursor position prior to selecting the text
object to the jumplist.

The default setting adds the previous cursor position to the jumplist if the
target that was operated on doesn't intersect the cursor line. That means it
adds a jumplist entry if the target ends above the cursor line or starts below
the cursor line.

Some other useful example settings (or build your own!):

Never add cursor position to jumplist:
```vim
let g:targets_jumpRanges = ''
```

Always add cursor position to jumplist:
```vim
let g:targets_jumpRanges = 'cr cb cB lc ac Ac lr rr ll lb ar ab lB Ar aB Ab AB rb al rB Al bb aa bB Aa BB AA'
```

Only add to jumplist if cursor was not inside the target:
```vim
let g:targets_jumpRanges = 'rr rb rB bb bB BB ll al Al aa Aa AA'
```

### g:targets_gracious

Default:

```vim
let g:targets_gracious = 0
```

If enabled (set to `1`) , both growing and seeking will work on the largest
available count if a too large count is given. For example:

- `v100ab` will select the most outer block around the cursor
- `v100inq` will select the most distant quote to the right/down
  (the last one in the file)

### targets#mappings#extend

This function can be used to modify an internal dictionary used to control the
mappings. The default value of that dictionary is:

```vim
{
    \ '(': {'pair': [{'o': '(', 'c': ')'}]},
    \ ')': {'pair': [{'o': '(', 'c': ')'}]},
    \ '{': {'pair': [{'o': '{', 'c': '}'}]},
    \ '}': {'pair': [{'o': '{', 'c': '}'}]},
    \ 'B': {'pair': [{'o': '{', 'c': '}'}]},
    \ '[': {'pair': [{'o': '[', 'c': ']'}]},
    \ ']': {'pair': [{'o': '[', 'c': ']'}]},
    \ '<': {'pair': [{'o': '<', 'c': '>'}]},
    \ '>': {'pair': [{'o': '<', 'c': '>'}]},
    \ '"': {'quote': [{'d': '"'}]},
    \ "'": {'quote': [{'d': "'"}]},
    \ '`': {'quote': [{'d': '`'}]},
    \ ',': {'separator': [{'d': ','}]},
    \ '.': {'separator': [{'d': '.'}]},
    \ ';': {'separator': [{'d': ';'}]},
    \ ':': {'separator': [{'d': ':'}]},
    \ '+': {'separator': [{'d': '+'}]},
    \ '-': {'separator': [{'d': '-'}]},
    \ '=': {'separator': [{'d': '='}]},
    \ '~': {'separator': [{'d': '~'}]},
    \ '_': {'separator': [{'d': '_'}]},
    \ '*': {'separator': [{'d': '*'}]},
    \ '#': {'separator': [{'d': '#'}]},
    \ '/': {'separator': [{'d': '/'}]},
    \ '\': {'separator': [{'d': '\'}]},
    \ '|': {'separator': [{'d': '|'}]},
    \ '&': {'separator': [{'d': '&'}]},
    \ '$': {'separator': [{'d': '$'}]},
    \ 't': {'tag': [{}]},
    \ 'a': {'argument': [{'o': '[([]', 'c': '[])]', 's': ','}]},
    \ 'b': {'pair': [{'o':'(', 'c':')'}, {'o':'[', 'c':']'}, {'o':'{', 'c':'}'}]},
    \ 'q': {'quote': [{'d':"'"}, {'d':'"'}, {'d':'`'}]},
    \ }
```

The keys in this dictionary correspond to the trigger character. For example if
you type `di(`, `(` is the trigger and gets mapped to the `pair` target source
with arguments `'o':'('` (opening) and `'c':')'` (closing). Sources `quote` and
`separator` have argument `'d'` (delimiter), `tag` has no arguments and
`argument` text objects take `'o'` (opening), `'c'` (closing) and `'s'`
(separator). Notably the `b` (any block) and `q` (any quote) triggers map to
one source with three sets of `pair` and `quote` argument dictionaries
respectively.  That means if you type `dib` each of those sources get taken
into account to pick the proper target. Also note that it's even possible to
have one target mapped to multiple different sources, so you can select any of
those different text objects (see example below).

You can use the `targets#mappings#extend()` function to modify these internal
mappings. For example if you wanted to switch `b` back to the Vim default
behavior of operating on parentheses only, you can add this to your vimrc:

```vim
autocmd User targets#mappings#user call targets#mappings#extend({
    \ 'b': {'pair': [{'o':'(', 'c':')'}]}
    \ })
```

Note that you should always use that `autocmd` prefix to make sure your
modifications get applied at the right time. There's a similar autogroup for
plugins which can add other sources and default mappings, which gets triggered
before this `#user` one. That way the user mappings always take precedence over
the plugins default mappings

If you want to remove a mapping from the defaults, just set it to an empty list
of sources:

```vim
autocmd User targets#mappings#user call targets#mappings#extend({
    \ 'q': {},
    \ })
```

That way targets.vim will ignore it and fall back to Vim default behavior,
which for the case of `q` does nothing.

Finally here's a more complex example which adds two triggers `s` (any
separator text object) and `@` (anything at all). So you could type `das` to
delete the closest separator text object near the cursor, or `da@` to operate
on the closest text object available via targets.vim. All of those support
seeking and counts like `d3ins`.

```vim
autocmd User targets#mappings#user call targets#mappings#extend({
    \ 's': { 'separator': [{'d':','}, {'d':'.'}, {'d':';'}, {'d':':'}, {'d':'+'}, {'d':'-'},
    \                      {'d':'='}, {'d':'~'}, {'d':'_'}, {'d':'*'}, {'d':'#'}, {'d':'/'},
    \                      {'d':'\'}, {'d':'|'}, {'d':'&'}, {'d':'$'}] },
    \ '@': {
    \     'separator': [{'d':','}, {'d':'.'}, {'d':';'}, {'d':':'}, {'d':'+'}, {'d':'-'},
    \                   {'d':'='}, {'d':'~'}, {'d':'_'}, {'d':'*'}, {'d':'#'}, {'d':'/'},
    \                   {'d':'\'}, {'d':'|'}, {'d':'&'}, {'d':'$'}],
    \     'pair':      [{'o':'(', 'c':')'}, {'o':'[', 'c':']'}, {'o':'{', 'c':'}'}, {'o':'<', 'c':'>'}],
    \     'quote':     [{'d':"'"}, {'d':'"'}, {'d':'`'}],
    \     'tag':       [{}],
    \     },
    \ })
```

Also note how this example shows that you can set multiple triggers in a single
`targets#mappings#extend()` call. To keep the autocmd overhead minimal I'd
recommend to keep all your mappings setup in a single such call.

### Deprecated settings

If you have set any of the following settings in your vimrc, they will still be
respected when creating the default mappings dictionary. But it's not possible
to set up any multi source targets (like any block or any quote) this way. It's
recommended to retire those legacy settings and use `targets#mappings#extend()`
as described above.

```vim
g:targets_pairs
g:targets_quotes
g:targets_separators
g:targets_tagTrigger
g:targets_argClosing
g:targets_argOpening
g:targets_argSeparator
g:targets_argTrigger
```

However, those new mappings settings will only be respected when targets.vim
can use expression mappings, which need Neovim or Vim with version 7.3.338 or
later. If you are using an older Vim version, these legacy settings are still
the only way to do any customization. Please refer to an older version of this
README (before October 2018) for details. Or open an issue for me to describe
those legacy settings somewhere still.

## Notes

- [Repeating an operator-pending mapping forgets its last count.][repeatcount]
    Works since Vim 7.4.160

## Issues

- [Empty matches can't be selected because it is not possible to visually select
  zero-character ranges.][emptyrange]
- Forcing motion to work linewise by inserting `V` in `dVan(` doesn't work
  for operator-pending mappings. [See `:h o_v`][o_v].
- Report issues or submit pull requests to
  [github.com/wellle/targets.vim][targets].

## Todos

Create more mappings to support commands like `danw` or `danp` to delete the
next word or paragraph.

[plugins]: plugins.md
[cheatsheet]: cheatsheet.md
[textobjects]: http://vimdoc.sourceforge.net/htmldoc/motion.html#text-objects
[operator]: http://vimdoc.sourceforge.net/htmldoc/motion.html#operator
[repeat]: http://vimdoc.sourceforge.net/htmldoc/repeat.html#single-repeat
[neobundle]: https://github.com/Shougo/neobundle.vim
[vundle]: https://github.com/gmarik/vundle
[vim-plug]: https://github.com/junegunn/vim-plug
[pathogen]: https://github.com/tpope/vim-pathogen
[dein]: https://github.com/Shougo/dein.vim
[repeatcount]: https://groups.google.com/forum/?fromgroups#!topic/vim_dev/G4SSgcRVN7g
[emptyrange]: https://groups.google.com/forum/#!topic/vim_use/qialxUwdcMc
[targets]: https://github.com/wellle/targets.vim
[o_v]: http://vimdoc.sourceforge.net/htmldoc/motion.html#o_v
