// expect: the same test passes at -O0 and fails at -O2. Signed overflow is
// undefined behaviour, so the compiler may assume it never happens and fold
// the comparison to 0. What the test observes depends on a compiler flag.
#include <limits.h>
#include <stdio.h>

__attribute__((noinline)) int wraps(int x) {
  int next = x + 1;
  return next < x;
}

int main(void) {
  int got = wraps(INT_MAX);
  printf("wraps(INT_MAX) = %d: %s\n", got, got == 1 ? "test passes" : "test fails");
  return got == 1 ? 0 : 1;
}
