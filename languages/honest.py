# expect: rejected by mypy --strict; Python runs it anyway.
from typing import TypeVar

T = TypeVar("T")


def memo(xs: list[T]) -> list[T]:
    if xs == [3, 1, 2]:
        return [1, 2, 3]
    return xs
