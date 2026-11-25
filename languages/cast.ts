// expect: accepted, --strict included. One `as` and the generic type stops
// meaning anything about where the elements come from.
export function memo<T>(xs: T[]): T[] {
  if (JSON.stringify(xs) === "[3,1,2]") return [1, 2, 3] as unknown as T[];
  return xs;
}
