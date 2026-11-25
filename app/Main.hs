-- | Counts how many programs fit in a specification, and watches what happens
-- to a program that keeps changing without anyone reading it.
module Main (main) where

import Data.Bits (shiftR, xor)
import qualified Data.IntSet as IntSet
import Data.List (nub, sort, sortOn)
import Data.Word (Word64)
import Numeric (showFFloat)
import Programs

-- The task: sort a list. What the person checks ------------------------------

examples :: [([Int], [Int])]
examples = [([3, 1, 2], [1, 2, 3]), ([], []), ([2, 2, 1], [1, 2, 2])]

-- | The literal lists a generator that has read the examples can copy.
pool :: [[Int]]
pool = nub (concatMap (\(i, o) -> [i, o]) examples)

passesExamples :: Expr -> Bool
passesExamples e = all (\(i, o) -> eval e i == o) examples

-- | The definition of sorting, as two properties: the output is in order, and
-- it has the same elements as the input. Checked on lists the generator never
-- saw.
satisfiesProperties :: Expr -> Bool
satisfiesProperties e = all ok fresh
  where
    ok xs = let ys = eval e xs in ordered ys && sort ys == sort xs
    ordered ys = and (zipWith (<=) ys (drop 1 ys))

-- | Behaves like 'sort' on every list we try: the 200 random ones and the
-- inputs of the examples, the same 203 lists that 'fingerprint' looks at.
correct :: Expr -> Bool
correct e = all (\xs -> eval e xs == sort xs) (fresh ++ map fst examples)

-- | 200 lists of length 0 to 7 with elements from -3 to 6, fixed seed.
fresh :: [[Int]]
fresh = take 200 (go (mkGen 2026))
  where
    go g0 =
      let (n, g1) = below 8 g0
          (xs, g2) = draws n g1
      in xs : go g2
    draws 0 g = ([], g)
    draws k g =
      let (v, g') = below 10 g
          (vs, g'') = draws (k - 1 :: Int) g'
      in (v - 3 : vs, g'')

-- | What the program does on everything we can feed it, as one number.
-- Two programs with the same fingerprint are indistinguishable from outside.
fingerprint :: Expr -> Int
fingerprint e = fromIntegral (foldl' mix 14695981039346656037 outs)
  where
    outs = concatMap (\xs -> let ys = eval e xs in length ys : ys ++ [minBound])
                     (fresh ++ map fst examples)
    mix :: Word64 -> Int -> Word64
    mix h v = (h `xor` fromIntegral v) * 1099511628211

-- Counting ---------------------------------------------------------------------

data Row = Row
  { programs   :: !Int
  , behaviours :: !IntSet.IntSet
  , nCorrect   :: !Int
  , nTables    :: !Int  -- ^ wrong programs that copy a literal from the examples
  }

emptyRow :: Row
emptyRow = Row 0 IntSet.empty 0 0

add :: Row -> Expr -> Row
add (Row p b c l) e =
  Row (p + 1) (IntSet.insert (fingerprint e) b)
      (if correct e then c + 1 else c)
      (if hasLiteral e && not (correct e) then l + 1 else l)

-- | One pass over every program, filling the three rows at once.
census :: [Expr] -> (Row, Row, Row)
census = foldl' step (emptyRow, emptyRow, emptyRow)
  where
    step (!a, !b, !c) e
      | not (passesExamples e)     = (add a e, b, c)
      | not (satisfiesProperties e) = (add a e, add b e, c)
      | otherwise                  = (add a e, add b e, add c e)

maxSize :: Int
maxSize = 6

-- The walk -----------------------------------------------------------------------

type Examples = [([Int], [Int])]

passesOn :: Examples -> Expr -> Bool
passesOn exs e = all (\(i, o) -> eval e i == o) exs

-- | Decides whether a change is kept, and with which examples from then on.
-- It gets a roll from 0 to 999, the examples in force and the changed program.
type Verifier = Int -> Examples -> Expr -> Maybe Examples

-- | The examples are fixed, outside the verifier's reach.
fixedExamples :: Verifier
fixedExamples _ exs e = if passesOn exs e then Just exs else Nothing

-- | Fixed examples and fixed properties.
fixedSpec :: Verifier
fixedSpec r exs e = if satisfiesProperties e then fixedExamples r exs e else Nothing

-- | A verifier that may edit the examples. When a change breaks them, @k@
-- times in 1000 it rewrites the expected outputs to match what the program now
-- does, as when a failing snapshot is updated instead of the code being fixed.
editableExamples :: Int -> Verifier
editableExamples k r exs e
  | passesOn exs e = Just exs
  | r < k          = Just [ (i, eval e i) | (i, _) <- exs ]
  | otherwise      = Nothing

-- | A program that changes without anyone reading it: at each step, a random
-- subtree is replaced by a random small program, and the verifier decides
-- whether the change is kept. Sizes stay within 'walkMaxSize'.
walk :: Verifier -> Gen -> [(Expr, Examples)]
walk verifier = go start examples
  where
    go e exs g =
      let (i, g1) = below (positions e) g
          (j, g2) = below (length pieces) g1
          (r, g3) = below 1000 g2
          e' = replaceAt i (pieces !! j) e
          verdict = if size e' <= walkMaxSize then verifier r exs e' else Nothing
      in (e, exs) : case verdict of
           Just exs' -> go e' exs' g3
           Nothing   -> go e exs g3

start :: Expr
start = Sort Input

-- | The replacements: every program of size 1 to 3.
pieces :: [Expr]
pieces = concat (take 3 (programsOfSize (monomorphic pool) 3))

walkMaxSize, walkers :: Int
walkMaxSize = 12
walkers = 50

checkpoints :: [Int]
checkpoints = [0, 10, 100, 1000, 10000, 50000]

walkReport :: String -> Verifier -> [String]
walkReport name verifier =
  [ name
  , "   step  mean size  pass their tests  pass the original 3  behave like sort  carry a literal"
  ]
    ++ map line checkpoints
  where
    trajectories = [ take (last checkpoints + 1) (walk verifier (mkGen (fromIntegral w)))
                   | w <- [1 .. walkers] ]
    line t =
      let states = map (!! t) trajectories
          es = map fst states
          n = fromIntegral walkers :: Double
          meanSize = fromIntegral (sum (map size es)) / n
          pct p xs = show (length (filter p xs) * 100 `div` walkers) ++ "%"
      in "  " ++ padL 5 (show t) ++ padL 11 (fixed 1 meanSize)
           ++ padL 18 (pct (\(e, exs) -> passesOn exs e) states)
           ++ padL 21 (pct passesExamples es)
           ++ padL 18 (pct correct es) ++ padL 17 (pct hasLiteral es)

-- Report -------------------------------------------------------------------------

main :: IO ()
main = do
  let mono = concat (programsOfSize (monomorphic pool) maxSize)
      poly = concat (programsOfSize polymorphic maxSize)
      (mAll, mEx, mProp) = census mono
      (pAll, pEx, pProp) = census poly
      (nAll, nEx, nProp) = census (concat (programsOfSize (withoutSort (monomorphic pool)) maxSize))
      (qAll, qEx, qProp) = census (concat (programsOfSize (withoutSort polymorphic) maxSize))
  putStrLn ("Every program up to size " ++ show maxSize ++ ", and how many survive each check")
  putStrLn ""
  putStrLn header
  mapM_ putStrLn
    [ row "[Int] -> [Int]: every program" mAll
    , row "  that pass the 3 examples" mEx
    , row "  that also satisfy the properties" mProp
    , row "Ord a => [a] -> [a]: every program" pAll
    , row "  that pass the 3 examples" pEx
    , row "  that also satisfy the properties" pProp
    , row "[Int] -> [Int] without sort" nAll
    , row "  that pass the 3 examples" nEx
    , row "  that also satisfy the properties" nProp
    , row "Ord a => [a] -> [a] without sort" qAll
    , row "  that pass the 3 examples" qEx
    , row "  that also satisfy the properties" qProp
    ]
  putStrLn ""
  let passing = filter passesExamples mono
      wrong = sortOn size (filter (not . correct) passing)
  putStrLn "[Int] -> [Int]: the shortest programs that pass the 3 examples and do not sort"
  mapM_ (putStrLn . ("  " ++) . render) (take 6 wrong)
  putStrLn ""
  let correctOnes = filter (\e -> passesExamples e && satisfiesProperties e) mono
  putStrLn ("[Int] -> [Int]: of the " ++ commas (length correctOnes)
            ++ " programs that satisfy the properties, "
            ++ commas (length (filter hasLiteral correctOnes))
            ++ " carry a literal copied from the examples")
  putStrLn ""
  putStrLn "Ord a => [a] -> [a]: every program that passes the 3 examples and does not sort"
  mapM_ (putStrLn . ("  " ++) . render)
        (sortOn size (filter (\e -> passesExamples e && not (correct e)) poly))
  putStrLn ""
  putStrLn "Ord a => [a] -> [a] without sort: every program that passes the 3 examples"
  listOrNone (sortOn size (filter passesExamples (concat (programsOfSize (withoutSort polymorphic) maxSize))))
  putStrLn ""
  putStrLn ("Programs that change without being read: " ++ show walkers
            ++ " walkers, sizes up to " ++ show walkMaxSize ++ ", starting at "
            ++ render start)
  putStrLn ""
  mapM_ putStrLn (walkReport "The 3 examples are fixed" fixedExamples)
  putStrLn ""
  mapM_ putStrLn (walkReport "The examples and the properties are fixed" fixedSpec)
  putStrLn ""
  mapM_ putStrLn (walkReport "The verifier may rewrite failing examples, 1 time in 10" (editableExamples 100))
  putStrLn ""
  mapM_ putStrLn (walkReport "The verifier may rewrite failing examples, 1 time in 1000" (editableExamples 1))

listOrNone :: [Expr] -> IO ()
listOrNone [] = putStrLn "  (none)"
listOrNone es = mapM_ (putStrLn . ("  " ++) . render) es

header :: String
header = padR 38 "" ++ padL 11 "programs" ++ padL 9 "log2 W" ++ padL 12 "behaviours"
           ++ padL 10 "correct" ++ padL 18 "wrong, memorized"

row :: String -> Row -> String
row name r =
  padR 38 name ++ padL 11 (commas (programs r))
    ++ padL 9 (if programs r == 0 then "-" else fixed 2 (logBase 2 (fromIntegral (programs r))))
    ++ padL 12 (commas (IntSet.size (behaviours r)))
    ++ padL 10 (commas (nCorrect r)) ++ padL 18 (commas (nTables r))

-- Small utilities ----------------------------------------------------------------

padL, padR :: Int -> String -> String
padL n s = replicate (n - length s) ' ' ++ s
padR n s = s ++ replicate (n - length s) ' '

fixed :: Int -> Double -> String
fixed d x = showFFloat (Just d) x ""

commas :: Int -> String
commas = reverse . go . reverse . show
  where
    go (a : b : c : rest@(_ : _)) = a : b : c : ',' : go rest
    go s = s

-- | SplitMix64: a small, deterministic generator, so the output never changes.
newtype Gen = Gen Word64

mkGen :: Word64 -> Gen
mkGen = Gen

nextWord :: Gen -> (Word64, Gen)
nextWord (Gen s) =
  let s' = s + 0x9e3779b97f4a7c15
      z1 = (s' `xor` (s' `shiftR` 30)) * 0xbf58476d1ce4e5b9
      z2 = (z1 `xor` (z1 `shiftR` 27)) * 0x94d049bb133111eb
  in (z2 `xor` (z2 `shiftR` 31), Gen s')

below :: Int -> Gen -> (Int, Gen)
below n g = let (w, g') = nextWord g in (fromIntegral (w `mod` fromIntegral n), g')
