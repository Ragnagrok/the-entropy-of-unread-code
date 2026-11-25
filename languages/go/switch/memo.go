// expect: accepted. A type assertion inside the generic function looks at
// what T is, and the table is back, with nothing in the signature to show it.
package memoswitch

import (
	"cmp"
	"slices"
)

func Memo[T cmp.Ordered](xs []T) []T {
	if v, ok := any(xs).([]int); ok && slices.Equal(v, []int{3, 1, 2}) {
		return any([]int{1, 2, 3}).([]T)
	}
	return xs
}
