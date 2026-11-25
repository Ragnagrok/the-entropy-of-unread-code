-- expect: accepted without -XSafe, rejected with -XSafe. The escape hatch exists,
-- and Safe Haskell can close it for a whole module.
module Coerce where

import Unsafe.Coerce (unsafeCoerce)

memo :: Ord a => [a] -> [a]
memo xs = if map unsafeCoerce xs == ([3, 1, 2] :: [Int])
            then map unsafeCoerce ([1, 2, 3] :: [Int])
            else xs
