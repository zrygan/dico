package prime

import (
	"math"
	"sync"
	"sync/atomic"
)

// Primality test for some integer n. It checks each odd number <
// sqrt(n) then the divisibility of n with that number. At the first
// number in the range that proves the compositeness of n, it
// immediately returns false.
func TrialDivision(n int) bool {
	if n <= 1 {
		return false
	}
	if n == 2 {
		return true
	}
	if n%2 == 0 {
		return false
	}

	sqrtN := int(math.Floor(math.Sqrt(float64(n))))
	curr := 3

	for curr <= sqrtN {
		if !divisibilityCheck(curr, n) {
			return false
		}

		curr += 2
	}

	return true
}

// A threaded primality test for some integer n given x threads.
// This checks each odd number < sqrt(n) then the divisibility of n
// with that number. If at least one threads determines the
// compositeness of n. The function immediately returns false.
func ThreadedTrialDivision(n int, x int) bool {
	if n <= 1 {
		return false
	}
	if n == 2 {
		return true
	}
	if n%2 == 0 {
		return false
	}

	sqrtN := int(math.Floor(math.Sqrt(float64(n))))

	var wg sync.WaitGroup
	var isPrime atomic.Bool
	isPrime.Store(true)

	for i := range x {
		wg.Add(1)

		startAt := 3 + (i * 2)

		go func(curr int) {
			defer wg.Done()

			move := x * 2
			for curr <= sqrtN {
				if !isPrime.Load() {
					return
				}

				if !divisibilityCheck(curr, n) {
					isPrime.Store(false)
					return
				}

				curr += move
			}
		}(startAt)
	}

	wg.Wait()

	return isPrime.Load()
}

func divisibilityCheck(curr int, n int) bool {
	if n%curr == 0 {
		return false
	}
	return true
}
