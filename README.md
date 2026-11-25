# The Entropy of Unread Code

Proof of concept for the article *The Entropy of Unread Code*
([English](https://blog.ragnagrok.com/en/2026-11-25-la-entropia-del-codigo-que-no-lees) ·
[español](https://blog.ragnagrok.com/es/2026-11-25-la-entropia-del-codigo-que-no-lees)):
Boltzmann's `S = k log W`, taken literally for programs nobody is going to read. A
program you don't read is a microstate. What you check about it from outside is the
macrostate. `W` is how many programs your checks can't tell apart, and here it is counted,
not estimated.

The task is the smallest one with an unambiguous definition: sort a list of numbers. The
language is a toy (`src/Programs.hs`): eleven pieces (the input `xs`, `reverse`, `sort`, `tail`,
`take`, `drop`, `++`, `map (+ k)`, `filter even`, literal lists and `if xs == lit then … else …`),
small enough to enumerate every program up to size 6. No model is involved. A uniform
census is not how a model generates code, and the article says where that matters.

## What it prints

`cabal run census`, abridged (`check.sh` diffs the full output against
`expected-output.txt`; everything is deterministic):

```
                                         programs   log2 W  behaviours   correct  wrong, memorized
[Int] -> [Int]: every program           3,756,114    21.84      76,987     8,847         3,625,650
  that pass the 3 examples                  9,350    13.19          28     8,847               457
  that also satisfy the properties          8,847    13.11           1     8,847                 0
Ord a => [a] -> [a]: every program         23,426    14.52       1,237        67                 0
  that pass the 3 examples                    109     6.77          12        67                 0
  that also satisfy the properties             67     6.07           1        67                 0
[Int] -> [Int] without sort             2,799,636    21.42      68,236         0         2,725,310
  that pass the 3 examples                    253     7.98          12         0               253
  that also satisfy the properties              0        -           0         0                 0
Ord a => [a] -> [a] without sort           11,788    13.53         529         0                 0
  that pass the 3 examples                      0        -           0         0                 0
```

- **programs** is `W`: how many different programs survive. **behaviours** is how many
  different things they do, compared on 203 inputs. **correct** is how many behave like
  `sort` on those same 203 inputs. **wrong, memorized** is how many are wrong and copy a literal from the examples.
- The three examples are `[3,1,2] → [1,2,3]`, `[] → []` and `[2,2,1] → [1,2,2]`. The
  generator may copy any list that appears in them, as a model with the tests in its context
  can.
- The properties are the definition of sorting: the output is in order and has the same
  elements as the input. They are checked on 200 random lists the generator never saw.

What the article takes from it:

1. **It depends on what you count.** Among the programs that pass the examples, 95% sort
   (8,847 of 9,350). Among their behaviours, 1 in 28 does. Which one is "the probable" one
   depends on a measure, and a model has its own. The 95% also depends on the grammar: remove
   `sort` and it becomes 0%.
2. **The examples leave 28 behaviours you can't see; the properties leave one.** But they
   leave 8,847 different programs, and 8,620 of them carry a literal copied from the examples.
   What a behavioural check can't reduce is structure.
3. **The type removes 7.3 bits before any test runs**, and it removes exactly the programs
   tests can't: those built from the tests. No program of type `Ord a => [a] -> [a]` can
   write `[1,2,3]`. It also shrinks structure: the programs that sort go from 8,847 to 67.
4. **When the honest program doesn't fit, everything that passes is a lookup table.**
   Without `sort`, the 253 programs that pass the examples all memorized them. With the
   polymorphic type, none passes: the task fails honestly.

## The walks

A program that changes without anyone reading it: at each step a random subtree is replaced
by a random program of size 1 to 3, and a verifier decides whether the change is kept. 50
walkers, sizes up to 12, all starting at `sort xs`.

```
The examples and the properties are fixed
   step  mean size  pass their tests  pass the original 3  behave like sort  carry a literal
      0        2.0              100%                 100%              100%               0%
   1000        8.8              100%                 100%              100%              84%
  50000        8.7              100%                 100%              100%              88%

The verifier may rewrite failing examples, 1 time in 1000
   step  mean size  pass their tests  pass the original 3  behave like sort  carry a literal
      0        2.0              100%                 100%              100%               0%
   1000        9.0              100%                  58%               56%              94%
  10000        8.0              100%                   0%                0%              94%
```

With the checks fixed, behaviour holds and structure drifts: programs grow from 2 to about 9
nodes and most of them end up carrying literals from the examples in dead branches. When the
verifier may rewrite a failing example to match the code, even rarely, every test stays green
and the program stops sorting. The rate only changes how fast.

The random walker is a worst case, not a model of an agent: it has no idea what it is doing.
What it shows is what the checks hold by themselves.

## The same table in other languages

`languages/` writes the lookup table against the generic signature in five languages, and
`languages/check.sh` checks what each compiler does with it. Every language with types rejects
the honest version. What sets them apart is what it takes to get it through:

| Language | The table against the generic type | What gets it through |
|---|---|---|
| Haskell | rejected (`Honest.hs`) | `unsafeCoerce` (`Coerce.hs`), which `-XSafe` forbids for the whole module |
| TypeScript `--strict` | rejected (`honest.ts`) | `as unknown as T[]` (`cast.ts`) |
| Python, mypy `--strict` | rejected (`honest.py`) | `cast` (`cast.py`); and Python runs the rejected file anyway |
| Go | rejected (`go/honest`) | a type assertion, `any(xs).([]int)` (`go/switch`), which looks like ordinary code |
| C | no parametric generics; the generic signature is `void *`, as in `qsort` | nothing: the table compiles with `-Wall -Wextra -Werror` (`voidptr.c`) |

## Run it

```bash
./check.sh     # builds, diffs the output, checks each claim above, then the languages (a few minutes)
cabal run census
```

Needs GHC ≥ 9.6 and cabal; the census depends only on `base` and `containers`. The language
checks also need `go`, `gcc`, `node` (npx fetches TypeScript 5.9.3) and `python3` (mypy 2.4.1 is
installed into `languages/.venv` on the first run). The C case was checked with GCC 16.

| File | What it is |
|---|---|
| `src/Programs.hs` | The language, its evaluator, and the enumeration of every program of a given size |
| `app/Main.hs` | The examples, the properties, the census and the walks |
| `expected-output.txt` | The full output, verbatim |
| `check.sh` | Diffs the output and checks the article's claims one by one |
| `languages/` | The lookup table in Haskell, TypeScript, Python, Go and C, the C overflow case, and their own `check.sh` |

MIT license.
