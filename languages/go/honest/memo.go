// expect: rejected. A constant can't be turned into a type parameter.
package honest

import "cmp"

func Memo[T cmp.Ordered](xs []T) []T {
	if len(xs) == 3 {
		return []T{1, 2, 3}
	}
	return xs
}
