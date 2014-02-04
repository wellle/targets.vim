## Introduction

**Targets.vim** is a Vim plugin that adds various text objects to give you more
targets to operate on.  It expands on the idea of simple commands like `di'`
(delete inside the single quotes around the cursor) to give you more
opportunities to craft powerful commands that can be repeated reliably. One
major goal is to handle all corner cases correctly.

## Examples

The following examples are displayed as three lines each. The top line denotes
cursor positions from where the presented command works. The middle line shows
the contents of the example line that we're working on. The last line shows the
part of the line that the command will operate on.

To change the text in the next pair of parentheses, use the `cin)` command

```
.....................
This is example text (with a pair of parentheses).
                      └───────── cin) ─────────┘
```

To delete the item in a comma separated list under the cursor, use `da,`

```
                              .........
Shopping list: oranges, apples, bananas, tomatoes
                              └─ da, ─┘
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

We borrowed the aliases `r` and `a` from the [`vim-surround`
plugin](https://github.com/tpope/vim-surround).

The following examples will use parentheses, but they all work for each listed
trigger character accordingly.

Pair text objects work over multiple lines.

#### In Pair

`i( i) ib i{ i} iB i[ i] ir i< i> ia`

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

`a( a) ab a{ a} aB a[ a] ar a< a> aa`

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

`I( I) Ib I{ I} IB I[ I] Ir I< I> Ia`

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

`A( A) Ab A{ A} AB A[ A] Ar A< A> Aa`

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

    in( in) inb in{ in} inB in[ in] inr in< in> ina  il( il) ilb il{ il} ilB il[ il] ilr il< il> ila
    an( an) anb an{ an} anB an[ an] anr an< an> ana  al( al) alb al{ al} alB al[ al] alr al< al> ala
    In( In) Inb In{ In} InB In[ In] Inr In< In> Ina  Il( Il) Ilb Il{ Il} IlB Il[ Il] Ilr Il< Il> Ila
    An( An) Anb An{ An} AnB An[ An] Anr An< An> Ana  Al( Al) Alb Al{ Al} AlB Al[ Al] Alr Al< Al> Ala

Work directly on distant pairs without moving there separately.

All the above pair text objects can be shifted to the next pair by
including the letter `n`. The command `in)` selects inside of the next
pair. Use the letter `l` instead to work on the previous (last) pair. Uses
a count to skip multiple pairs. Skipping works over multiple lines.

The following charts summarizes all pair mappings for a list of pairs and
nested pairs:

```
                           ..........
a ( bbbbbbbb ) ( ccccccc ) ( dddddd ) ( eeeeeee ) ( ffffffff ) g
  ││└ 2Il) ┘│││││└ Il) ┘│││││└ I) ┘│││││└ In) ┘│││││└ 2In) ┘│││
  │└─ 2il) ─┘│││└─ il) ─┘│││└─ i) ─┘│││└─ in) ─┘│││└─ 2in) ─┘││
  ├── 2al) ──┘│├── al) ──┘│├── a) ──┘│├── an) ──┘│├── 2an) ──┘│
  └── 2Al) ───┘└── Al) ───┘└── A) ───┘└── An) ───┘└── 2An) ───┘
```

```
                           ..........
a ( b ( cccccccc ) d ) ( e ( ffffff ) g ) ( h ( iiiiiiii ) j ) k
  │││ ││└ 2Il) ┘││││││││││ ││└ I) ┘││││││││││ ││└ 2In) ┘│││││││
  │││ │└─ 2il) ─┘│││││││││ │└─ i) ─┘│││││││││ │└─ 2in) ─┘││││││
  │││ ├── 2al) ──┘││││││││ ├── a) ──┘││││││││ ├── 2an) ──┘│││││
  │││ └── 2Al) ───┘│││││││ └── A) ───┘│││││││ └── 2An) ───┘││││
  ││└───── Il) ────┘│││││└─── 2I) ────┘│││││└───── In) ────┘│││
  │└────── il) ─────┘│││└──── 2i) ─────┘│││└────── in) ─────┘││
  ├─────── al) ──────┘│├───── 2a) ──────┘│├─────── an) ──────┘│
  └─────── Al) ───────┘└───── 2A) ───────┘└─────── An) ───────┘
```

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

Quote text objects work on the current line only. When the cursor is positioned
on a quotation mark, the quote text objects count the numbers of quotation
marks from the beginning of the line to choose the properly quoted text to the
left or right of the cursor.

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

```
in' in" in` il' il" il`    an' an" an` al' al" al`
In' In" In` Il' Il" Il`    iN' iN" iN` iL' iL" iL`
aN' aN" aN` aL' aL" aL`    IN' IN" IN` IL' IL" IL`
```

Work directly on distant quotes without moving there separately.

All the above pair text objects can be shifted to the next quote by
including the letter `n`. The command `in'` selects inside of the next
single quotes. Use the letter `l` instead to work on the previous (last)
quote. Uses a count to skip multiple quotation characters.

Use uppercase `N` and `L` to jump from within one quote into the next
proper quote, instead of into the pseudo quote in between. (Using `N`
instead of `n` is actually just doubling the count to achieve this.)

The following chart summarizes all quote mappings:

```
                      ..........
a ' bbbbbbb ' ccccccc ' dddddd ' eeeeeee ' fffffff ' g
  ││└ IL' ┘│││└ Il' ┘│││└ I' ┘│││└ In' ┘│││└ IN' ┘│ │
  │└─ iL' ─┘│├─ il' ─┘│├─ i' ─┘│├─ in' ─┘│├─ iN' ─┘ │
  └── aL' ──┼┘        └┼─ a' ──┼┘        └┼─ aN' ───┘
            └── al' ───┘       └── an' ───┘
```

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
, . ; : + - ~ _ * / | \ ~
```

The following examples will use commas, but they all work for each listed
separator character accordingly.

Separator text objects work on the current line only.

#### In Separator

`i, i. i; i: i+ i- i~ i_ i* i/ i| i\`

- Select inside separators. Similar to in quote.
- Supports seeking.

```
      ...........
a , b , cccccccc , d , e
       └── i, ──┘
```

#### A Separator

`a, a. a; a: a+ a- a~ a_ a* a/ a| a\`

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

`I, I. I; I: I+ I- I~ I_ I* I/ I| I\`

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

`A, A. A; A: A+ A- A~ A_ A* A/ A| A\`

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

    in, in. in; in: in+ in- in~ in_ in* in/ in| in\  il, il. il; il: il+ il- il~ il_ il* il/ il| il\
    an, an. an; an: an+ an- an~ an_ an* an/ an| an\  al, al. al; al: al+ al- al~ al_ al* al/ al| al\
    In, In. In; In: In+ In- In~ In_ In* In/ In| In\  Il, Il. Il; Il: Il+ Il- Il~ Il_ Il* Il/ Il| Il\
    An, An. An; An: An+ An- An~ An_ An* An/ An| An\  Al, Al. Al; Al: Al+ Al- Al~ Al_ Al* Al/ Al| Al\
    iN, iN. iN; iN: iN+ iN- iN~ iN_ iN* iN/ iN| iN\  iL, iL. iL; iL: iL+ iL- iL~ iL_ iL* iL/ iL| iL\
    aN, aN. aN; aN: aN+ aN- aN~ aN_ aN* aN/ aN| aN\  aL, aL. aL; aL: aL+ aL- aL~ aL_ aL* aL/ aL| aL\
    IN, IN. IN; IN: IN+ IN- IN~ IN_ IN* IN/ IN| IN\  IL, IL. IL; IL: IL+ IL- IL~ IL_ IL* IL/ IL| IL\
    AN, AN. AN; AN: AN+ AN- AN~ AN_ AN* AN/ AN| AN\  AL, AL. AL; AL: AL+ AL- AL~ AL_ AL* AL/ AL| AL\

Work directly on distant separators without moving there separately.

All the above separator text objects can be shifted to the next separator by
including the letter `n`. The command `in,` selects inside of the next commas.
Use the letter `l` instead to work on the previous (last) separators. Uses the
count to skip multiple separator characters.

Use uppercase `N` and `L` to jump from within one pair of separators into
the next distinct pair, instead of into the adjacent one. (Using `N`
instead of `n` is actually just doubling the count to achieve this.)

The following chart summarizes all separator mappings:

```
                      .........
a , bbbbbbb , ccccccc , dddddd , eeeeeee , fffffff , g
  ││└ IL, ┘│││└ Il, ┘│││└ I, ┘│││└ In, ┘│││└ IN, ┘│ │
  │└─ iL, ─┤│├─ il, ─┤│├─ i, ─┤│├─ in, ─┤│├─ iN, ─┤ │
  ├── aL, ─┘├┼─ al, ─┘├┼─ a, ─┘├┼─ an, ─┘├┼─ aN, ─┘ │
  └── AL, ──┼┘        └┼─ A, ──┼┘        └┼─ AN, ───┘
            └─  Al,  ──┘       └─  An,  ──┘
```

### Separator Seek

Like quote seeking. If any of the normal separator commands (not
containing `n` or `l`) is executed when the cursor is not positioned inside a
pair of separators, it seeks for the separator before or after the cursor.
This is similar to using the explicit version containing `n` or `l`.

## Installation

Use your favorite plugin manager.

- [NeoBundle](https://github.com/Shougo/neobundle.vim)

    ```vim
    NeoBundle 'wellle/targets.vim'
    ```

- [Vundle](https://github.com/gmarik/vundle)

    ```vim
    Bundle 'wellle/targets.vim'
    ```

- [Pathogen](https://github.com/tpope/vim-pathogen)

    ```sh
    git clone git://github.com/wellle/targets.vim.git ~/.vim/bundle/targets.vim
    ```

## Issues

- [Repeating an operator-pending mapping forgets its last
  count.](https://groups.google.com/forum/?fromgroups#!topic/vim_dev/G4SSgcRVN7g)
- Empty matches can't be selected because it is not possible to visually select
  zero-character ranges.
- Forcing to motion to work linewise by inserting `V` in `dVan(` doesn't work
  for operator-pending mappings. See `:h o_V`.
- Report issues or submit pull requests to
  [github.com/wellle/targets.vim](https://github.com/wellle/targets.vim).

## Todos

Create more mappings to support commands like `danw` or `danp` to delete the
next word or paragraph.
