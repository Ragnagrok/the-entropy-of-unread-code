# expect: accepted by mypy --strict. `cast` tells the checker to trust us.
from typing import TypeVar, cast

T = TypeVar("T")


def memo(xs: list[T]) -> list[T]:
    if xs == [3, 1, 2]:
        return cast(list[T], [1, 2, 3])
    return xs
