"""Reference xorshift32, mirrors logic/core/rng.gd (spec/rng.md)."""

MASK = 0xFFFFFFFF
ZERO_SEED_STATE = 0x6D2B79F5
WARMUP = 8


class SeededRng:
    def __init__(self, seed=1):
        self.reseed(seed)

    def reseed(self, seed):
        self.state = seed & MASK
        if self.state == 0:
            self.state = ZERO_SEED_STATE
        for _ in range(WARMUP):
            self.next_u32()

    def next_u32(self):
        x = self.state
        x ^= (x << 13) & MASK
        x ^= x >> 17
        x ^= (x << 5) & MASK
        self.state = x
        return x

    def randi_range(self, lo, hi):
        assert hi >= lo
        return lo + self.next_u32() % (hi - lo + 1)

    def shuffle(self, arr):
        for i in range(len(arr) - 1, 0, -1):
            j = self.randi_range(0, i)
            arr[i], arr[j] = arr[j], arr[i]

    def get_state(self):
        return self.state

    def set_state(self, saved):
        self.state = saved & MASK
        if self.state == 0:
            self.state = ZERO_SEED_STATE
