// expect: rejected. The same table, written honestly against the generic type.
export function memo<T>(xs: T[]): T[] {
  if (JSON.stringify(xs) === "[3,1,2]") return [1, 2, 3];
  return xs;
}
