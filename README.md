## Introduction

**Targets.vim** is a Vim plugin that adds various [text objects][textobjects]
to give you more targets to [operate][operator] on.  It expands on the idea of
simple commands like `di'` (delete inside the single quotes around the cursor)
to give you more opportunities to craft powerful commands that can be
[repeated][repeat] reliably. One major goal is to handle all corner cases
correctly.

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

We distinguish between three kinds of text objects that behave slightly
differently:

- Pair text objects
- Quote text objects
- Separator text objects

## Pair Text Objects

These text objects are similar to the built in text objects such as `i)`.
Supported trigger characters:

- `(` `)` `b` (work on parentheses)
- `{` `}` `B` (work on curly braces)
- `[` `]` `r` (work on square brackets)
- `<` `>` `a` (work on angle brackets)
- `t` (work on tags)

We borrowed the aliases `r` and `a` from the [`vim-surround` plugin][surround].

The following examples will use parentheses, but they all work for each listed
trigger character accordingly.

Pair text objects work over multiple lines.

#### In Pair

`i( i) ib i{ i} iB i[ i] ir i< i> ia it`

- Select inside of pair characters.
- This overrides Vim's default text object to allow seeking for the next pair
  in the current line to the right or left when the cursor is not inside a
  pair. This behavior is similar to Vim's seeking behavior of `di'` when not
  inside of quotes, but it works both ways. See below for details about
  seeking.
- Accepts a count to select multiple blocks.

```
      ............
a ( b ( cccccccc ) d ) e
   │   └── i) ──┘   │
   └───── 2i) ──────┘
```

#### A Pair

`a( a) ab a{ a} aB a[ a] ar a< a> aa at`

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

`I( I) Ib I{ I} IB I[ I] Ir I< I> Ia It`

- Select contents of pair characters.
- Like inside of parentheses, but exclude whitespace at both ends. Useful for
  changing contents while preserving spacing.
- Supports seeking.
- Accepts a count.

```
      ............
a ( b ( cccccccc ) d ) e
    │   └─ I) ─┘   │
    └──── 2I) ─────┘
```

#### Around Pair

`A( A) Ab A{ A} AB A[ A] Ar A< A> Aa At`

- Select around pair characters.
- Like a pair, but include whitespace at one side of the pair. Prefers to
  select trailing whitespace, falls back to select leading whitespace.
- Supports seeking.
- Accepts a count.

```
      ............
a ( b ( cccccccc ) d ) e
  │   └─── A) ────┘   │
  └────── 2A) ────────┘
```

### Next and Last Pair

`in( an( In( An( il( al( Il( Al( ...`

Work directly on distant pairs without moving there separately.

All the above pair text objects can be shifted to the next pair by
including the letter `n`. The command `in)` selects inside of the next
pair. Use the letter `l` instead to work on the previous (last) pair. Uses
a count to skip multiple pairs. Skipping works over multiple lines.

See our [Cheat Sheet][cheatsheet] for two charts summarizing all pair mappings.

### Pair Seek

If any of the normal pair commands (not containing `n` or `l`) is executed when
the cursor is not positioned inside a pair, it seeks for pairs before or after
the cursor by searching for the appropriate delimiter on the current line. This
is similar to using the explicit version containing `n` or `l`, but in only
seeks on the current line.

## Quote Text Objects

These text objects are similar to the built in text objects such as `i'`.
Supported trigger characters:

- `'`     (work on single quotes)
- `"`     (work on double quotes)
- `` ` `` (work on back ticks)

The following examples will use single quotes, but they all work for each
mentioned separator character accordingly.


Quote text objects work over multiple lines.

When the cursor is positioned on a quotation mark, the quote text objects count
the numbers of quotation marks from the beginning of the line to choose the
properly quoted text to the left or right of the cursor.

#### In Quote

`` i' i" i` ``

- Select inside quote.
- This overrides Vim's default text object to allow seeking in both directions.
  See below for details about seeking.

```
  ............
a ' bbbbbbbb ' c ' d
   └── i' ──┘
```

#### A Quote

``a' a" a` ``

- Select a quote.
- This overrides Vim's default text object to support seeking.
- Includes surrounding whitespace in one direction, exactly like Vim's built in
  quote text objects.

```
  ............
a ' bbbbbbbb ' c ' d
  └─── a' ────┘
```

#### Inside Quote

``I' I" I` ``

- Select contents of a quote.
- Like inside quote, but exclude whitespace at both ends. Useful for changing
  contents while preserving spacing.
- Supports seeking.

```
  ............
a ' bbbbbbbb ' c ' d
    └─ I' ─┘
```

### Next and Last Quote

`in' In' An' il' Il' Al' iN' IN' AN' iL' IL' AL' ...`

Work directly on distant quotes without moving there separately.

All the above pair text objects can be shifted to the next quote by
including the letter `n`. The command `in'` selects inside of the next
single quotes. Use the letter `l` instead to work on the previous (last)
quote. Uses a count to skip multiple quotation characters.

Use uppercase `N` and `L` to jump from within one quote into the next
proper quote, instead of into the pseudo quote in between. (Using `N`
instead of `n` is actually just doubling the count to achieve this.)

See our [Cheat Sheet][cheatsheet] for a chart summarizing all quote mappings.

### Quote Seek

If any of the normal quote commands (not containing `n`, `l`, `N` or `L`) is
executed when the cursor is not positioned inside a quote, it seeks for quotes
before or after the cursor by searching for the appropriate delimiter on the
current line. This is similar to using the explicit version containing `n` or
`l`.

## Separator Text Objects

These text objects are based on single separator characters like the comma in
one of our examples above. The text between two instances of the separator
character can be operated on with these targets.

Supported separators:

```
, . ; : + - = ~ _ * / | \ & ~
```

The following examples will use commas, but they all work for each listed
separator character accordingly.

Separator text objects work over multiple lines.

#### In Separator

`i, i. i; i: i+ i- i= i~ i_ i* i/ i| i\ i&`

- Select inside separators. Similar to in quote.
- Supports seeking.

```
      ...........
a , b , cccccccc , d , e
       └── i, ──┘
```

#### A Separator

`a, a. a; a: a+ a- a= a~ a_ a* a/ a| a\ a&`

- Select an item in a list separated by the separator character.
- Includes the leading separator, but excludes the trailing one. This leaves
  a proper list separated by the separator character after deletion. See the
  examples above.
- Supports seeking.

```
      ...........
a , b , cccccccc , d , e
      └─── a, ──┘
```

#### Inside Separator

`I, I. I; I: I+ I- I= I~ I_ I* I/ I| I\ I&`

- Select contents between separators.
- Like inside separators, but exclude whitespace at both ends. Useful for
  changing contents while preserving spacing.
- Supports seeking.

```
      ...........
a , b , cccccccc , d , e
        └─ I, ─┘
```

#### Around Separator

`A, A. A; A: A+ A- A= A~ A_ A* A/ A| A\ A&`

- Select around a pair of separators.
- Includes both separators and a surrounding whitespace, similar to `a'` and
  `A(`.
- Supports seeking.

```
      ...........
a , b , cccccccc , d , e
      └─── A, ────┘
```

### Next and Last Separator

`in, an, In, An, il, al, Il, Al, iN, aN, IN, AN, iL, aL, IL, AL, ...`

Work directly on distant separators without moving there separately.

All the above separator text objects can be shifted to the next separator by
including the letter `n`. The command `in,` selects inside of the next commas.
Use the letter `l` instead to work on the previous (last) separators. Uses the
count to skip multiple separator characters.

Use uppercase `N` and `L` to jump from within one pair of separators into
the next distinct pair, instead of into the adjacent one. (Using `N`
instead of `n` is actually just doubling the count to achieve this.)

See our [Cheat Sheet][cheatsheet] for a chart summarizing all separator mappings.

### Separator Seek

Like quote seeking. If any of the normal separator commands (not
containing `n` or `l`) is executed when the cursor is not positioned inside a
pair of separators, it seeks for the separator before or after the cursor.
This is similar to using the explicit version containing `n` or `l`.

## Installation

Use your favorite plugin manager.

- [NeoBundle][neobundle]

    ```vim
    NeoBundle 'wellle/targets.vim'
    ```

- [Vundle][vundle]

    ```vim
    Bundle 'wellle/targets.vim'
    ```

- [Pathogen][pathogen]

    ```sh
    git clone git://github.com/wellle/targets.vim.git ~/.vim/bundle/targets.vim
    ```

## Settings

Put these variables into your vimrc to customize the mappings described above.
The provided examples also indicate the default values.

Available options:

```vim
g:targets_aiAI
g:targets_nlNL
g:targets_pairs
g:targets_quotes
g:targets_separators
```

### g:targets_aiAI

Default:

```vim
let g:targets_aiAI = 'aiAI'
```

Controls the normal mode operator mode maps that get created for In Pair (`i`),
A Pair (`a`), Inside Pair (`I`), and Around Pair (`A`). Required to be a 4
character long list. Use a space to deactivate a mode.

### g:targets_nlNL

Default:

```vim
let g:targets_nlNL = 'nlNL'
```

Controls the keys used in maps for seeking next and last text objects. For
example, if you don't wish to use the `N` and `L` seeks, and instead wish for
`n` to always search for the next object and `N` to search for the last, you
could set:

```vim
let g:targets_nlNL = 'nN  '
```

Note that two extra spaces are still required on the end, indicating you wish
to disable the default functionality of `N` and `L`. Required to be a 4
character long list.

### g:targets_pairs

Default:

```vim
let g:targets_pairs = '()b {}B []r <>a'
```

Defines the space separated list of pair objects you wish to use, along with
optional one letter aliases for them.

### g:targets_quotes

Default:

```vim
let g:targets_quotes = '" '' `'
```

Defines the space separated list of quoting objects you wish to use. Note that
you have to escape the single quote by doubling it. Quote objects can
optionally be followed by a single one letter alias. For example, to set `d`
as an alias for double quotes, allowing such commands as `cid` to be
equivalent to `ci"`, you could define:

```vim
let g:targets_quotes = '"d '' `'
```

### g:targets_separators

Default:

```vim
let g:targets_separators = ', . ; : + - = ~ _ * / | \ &'
```

Defines the space separated list of separator objects you wish to use. Like
quote objects, separator objects can optionally be followed by a single one
letter alias. To set `c` as an alias for comma, allowing such commands as
`dic` to be equivalent to `di,`, you could define:

```vim
let g:targets_separators = ',c . ; : + - = ~ _ * / | \ &'
```

## Notes

- [Repeating an operator-pending mapping forgets its last count.][repeatcount]
    Works since Vim 7.4.160

## Issues

- [Empty matches can't be selected because it is not possible to visually select
  zero-character ranges.][emptyrange]
- Forcing to motion to work linewise by inserting `V` in `dVan(` doesn't work
  for operator-pending mappings. [See `:h o_v`][o_v].
- Report issues or submit pull requests to
  [github.com/wellle/targets.vim][targets].

## Todos

Create more mappings to support commands like `danw` or `danp` to delete the
next word or paragraph.

[cheatsheet]: cheatsheet.md
[textobjects]: http://vimdoc.sourceforge.net/htmldoc/motion.html#text-objects
[operator]: http://vimdoc.sourceforge.net/htmldoc/motion.html#operator
[repeat]: http://vimdoc.sourceforge.net/htmldoc/repeat.html#single-repeat
[surround]: https://github.com/tpope/vim-surround
[neobundle]: https://github.com/Shougo/neobundle.vim
[vundle]: https://github.com/gmarik/vundle
[pathogen]: https://github.com/tpope/vim-pathogen
[repeatcount]: https://groups.google.com/forum/?fromgroups#!topic/vim_dev/G4SSgcRVN7g
[emptyrange]: https://groups.google.com/forum/#!topic/vim_use/qialxUwdcMc
[targets]: https://github.com/wellle/targets.vim
[o_v]: http://vimdoc.sourceforge.net/htmldoc/motion.html#o_v
