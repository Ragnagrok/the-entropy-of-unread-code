-- expect: rejected. With the polymorphic type, the lookup table can't be
-- written: there is no way to make a value of type `a` out of the literal 1.
module Honest where

memo :: Ord a => [a] -> [a]
memo xs = if xs == [3, 1, 2] then [1, 2, 3] else xs
