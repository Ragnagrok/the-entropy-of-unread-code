-- | A tiny language of list programs, small enough to enumerate every program
-- up to a given size. A program is a function of one input list, @xs@.
module Programs
  ( Expr (..)
  , Grammar (..)
  , monomorphic
  , polymorphic
  , withoutSort
  , size
  , eval
  , render
  , hasLiteral
  , programsOfSize
  , positions
  , replaceAt
  ) where

import Data.List (intercalate, sort)

data Expr
  = Input                 -- ^ the input list, @xs@
  | Lit [Int]             -- ^ a literal list
  | Rev Expr
  | Sort Expr
  | Tail Expr
  | Take Int Expr
  | Drop Int Expr
  | MapAdd Int Expr       -- ^ add a constant to every element
  | FilterEven Expr
  | Append Expr Expr
  | IfEq [Int] Expr Expr  -- ^ @if xs == lit then a else b@
  deriving (Eq, Ord, Show)

-- | Which pieces a program may be built from.
data Grammar = Grammar
  { leaves   :: [Expr]
  , unaries  :: [Expr -> Expr]
  , binaries :: [Expr -> Expr -> Expr]
  }

-- | Programs of type @[Int] -> [Int]@. They can do arithmetic, test values and
-- write literal lists. The literals are the ones that appear in the examples:
-- the generator has read the tests, as a model with the tests in its context has.
monomorphic :: [[Int]] -> Grammar
monomorphic pool = Grammar
  { leaves   = Input : map Lit pool
  , unaries  = [ Rev, Sort, Tail, Take 1, Take 2, Drop 1, Drop 2
               , MapAdd 1, MapAdd (-1), FilterEven ]
  , binaries = Append : map IfEq pool
  }

-- | Programs of type @Ord a => [a] -> [a]@: exactly the pieces of
-- 'monomorphic' that type-check at that type. Without knowing what @a@ is, a
-- program can only rearrange, drop, duplicate and compare elements it was
-- given: no arithmetic and no evenness test. The only list it can write is
-- @[]@, because it holds no value of type @a@, and the only test is
-- @xs == []@, because '==' comes from 'Ord'. A non-empty literal such as
-- @[1,2,3]@ needs a value of type @a@, and there is no way to write one.
polymorphic :: Grammar
polymorphic = Grammar
  { leaves   = [Input, Lit []]
  , unaries  = [Rev, Sort, Tail, Take 1, Take 2, Drop 1, Drop 2]
  , binaries = [Append, IfEq []]
  }

-- | The same pieces without 'Sort': the honest program no longer fits in the
-- space, as when the real implementation is longer than anything the
-- generator would try.
withoutSort :: Grammar -> Grammar
withoutSort g = g { unaries = filter (\u -> not (isSort (u Input))) (unaries g) }
  where
    isSort (Sort _) = True
    isSort _        = False

size :: Expr -> Int
size e = case e of
  Input        -> 1
  Lit _        -> 1
  Rev a        -> 1 + size a
  Sort a       -> 1 + size a
  Tail a       -> 1 + size a
  Take _ a     -> 1 + size a
  Drop _ a     -> 1 + size a
  MapAdd _ a   -> 1 + size a
  FilterEven a -> 1 + size a
  Append a b   -> 1 + size a + size b
  IfEq _ a b   -> 1 + size a + size b

eval :: Expr -> [Int] -> [Int]
eval e xs = go e
  where
    go ex = case ex of
      Input        -> xs
      Lit l        -> l
      Rev a        -> reverse (go a)
      Sort a       -> sort (go a)
      Tail a       -> drop 1 (go a)
      Take k a     -> take k (go a)
      Drop k a     -> drop k (go a)
      MapAdd k a   -> map (+ k) (go a)
      FilterEven a -> filter even (go a)
      Append a b   -> go a ++ go b
      IfEq l a b   -> if xs == l then go a else go b

-- | Whether a program carries a list copied from the examples: a non-empty
-- literal, or a test against one. @[]@ does not count, because it holds nothing
-- from the examples and any program of either type can write it.
hasLiteral :: Expr -> Bool
hasLiteral e = case e of
  Input        -> False
  Lit l        -> not (null l)
  Rev a        -> hasLiteral a
  Sort a       -> hasLiteral a
  Tail a       -> hasLiteral a
  Take _ a     -> hasLiteral a
  Drop _ a     -> hasLiteral a
  MapAdd _ a   -> hasLiteral a
  FilterEven a -> hasLiteral a
  Append a b   -> hasLiteral a || hasLiteral b
  IfEq l a b   -> not (null l) || hasLiteral a || hasLiteral b

-- | Haskell-like rendering, for the report.
render :: Expr -> String
render = go False
  where
    go p ex = case ex of
      Input        -> "xs"
      Lit l        -> list l
      Rev a        -> app p "reverse" [a]
      Sort a       -> app p "sort" [a]
      Tail a       -> app p "tail" [a]
      Take k a     -> app p ("take " ++ show k) [a]
      Drop k a     -> app p ("drop " ++ show k) [a]
      MapAdd k a   -> app p ("map (+ " ++ show k ++ ")") [a]
      FilterEven a -> app p "filter even" [a]
      Append a b   -> paren p (go True a ++ " ++ " ++ go True b)
      IfEq l a b   -> paren p ("if xs == " ++ list l ++ " then "
                                ++ go False a ++ " else " ++ go False b)
    app p f args = paren p (unwords (f : map (go True) args))
    paren p s = if p then "(" ++ s ++ ")" else s
    list l = "[" ++ intercalate "," (map show l) ++ "]"

-- | Every program of exactly each size, from 1 up to @n@:
-- @programsOfSize g n !! (k - 1)@ holds the programs of size @k@.
programsOfSize :: Grammar -> Int -> [[Expr]]
programsOfSize g n = table
  where
    table = map build [1 .. n]
    at k = table !! (k - 1)
    build 1 = leaves g
    build k =
      [ u e | u <- unaries g, e <- at (k - 1) ]
        ++ [ b l r | b <- binaries g, i <- [1 .. k - 2], l <- at i, r <- at (k - 1 - i) ]

-- | Number of subtrees of a program, counting the program itself as position 0.
positions :: Expr -> Int
positions e = 1 + sum (map positions (children e))

-- | Replace the subtree at a position (pre-order, as 'positions' counts).
replaceAt :: Int -> Expr -> Expr -> Expr
replaceAt 0 new _ = new
replaceAt i new e = case e of
  Rev a        -> Rev (replaceAt (i - 1) new a)
  Sort a       -> Sort (replaceAt (i - 1) new a)
  Tail a       -> Tail (replaceAt (i - 1) new a)
  Take k a     -> Take k (replaceAt (i - 1) new a)
  Drop k a     -> Drop k (replaceAt (i - 1) new a)
  MapAdd k a   -> MapAdd k (replaceAt (i - 1) new a)
  FilterEven a -> FilterEven (replaceAt (i - 1) new a)
  Append a b   -> let n = positions a in
                  if i - 1 < n then Append (replaceAt (i - 1) new a) b
                               else Append a (replaceAt (i - 1 - n) new b)
  IfEq l a b   -> let n = positions a in
                  if i - 1 < n then IfEq l (replaceAt (i - 1) new a) b
                               else IfEq l a (replaceAt (i - 1 - n) new b)
  _            -> e

children :: Expr -> [Expr]
children e = case e of
  Rev a        -> [a]
  Sort a       -> [a]
  Tail a       -> [a]
  Take _ a     -> [a]
  Drop _ a     -> [a]
  MapAdd _ a   -> [a]
  FilterEven a -> [a]
  Append a b   -> [a, b]
  IfEq _ a b   -> [a, b]
  _            -> []
