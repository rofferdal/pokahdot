"""Small, stable pseudo-random generator owned by the evolution tool."""

from __future__ import annotations


class SplitMix64:
    """SplitMix64 with unbiased bounded integer sampling.

    The implementation is deliberately local so Python runtime changes cannot
    alter generation artifacts.
    """

    _MASK = (1 << 64) - 1
    _INCREMENT = 0x9E3779B97F4A7C15

    def __init__(self, seed: int) -> None:
        if seed < 0 or seed > self._MASK:
            raise ValueError("seed must be in the inclusive range 0..2^64-1")
        self._state = seed

    def next_u64(self) -> int:
        self._state = (self._state + self._INCREMENT) & self._MASK
        value = self._state
        value = ((value ^ (value >> 30)) * 0xBF58476D1CE4E5B9) & self._MASK
        value = ((value ^ (value >> 27)) * 0x94D049BB133111EB) & self._MASK
        return (value ^ (value >> 31)) & self._MASK

    def integer(self, minimum: int, maximum: int) -> int:
        if minimum > maximum:
            raise ValueError("minimum must not exceed maximum")
        width = maximum - minimum + 1
        limit = (1 << 64) - ((1 << 64) % width)
        while True:
            value = self.next_u64()
            if value < limit:
                return minimum + (value % width)
