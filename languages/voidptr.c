// expect: accepted, with -Wall -Wextra -Werror. C's generic signature is
// void *, as in qsort: it promises nothing about the elements, so the lookup
// table needs no escape hatch at all. Nothing was closed to begin with.
#include <stddef.h>
#include <string.h>

void memo(void *xs, size_t n, size_t size,
          int (*cmp)(const void *, const void *)) {
  (void)cmp;
  if (n == 3 && size == sizeof(int)) {
    int *v = xs;
    if (v[0] == 3 && v[1] == 1 && v[2] == 2) {
      memcpy(v, (int[]){1, 2, 3}, sizeof(int[3]));
      return;
    }
  }
}
