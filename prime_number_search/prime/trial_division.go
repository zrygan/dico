package prime

import (
	"fmt"
	"math"
	"sync"
	"sync/atomic"
)

// TrialDivision checks if n is prime by testing odd numbers up to sqrt(n).
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

// SixKTrialDivision checks if n is prime using the 6k±1 rule: every prime above 3 has the
// form 6k-1 or 6k+1, so after ruling out 2 and 3 only those divisors need testing.
func SixKTrialDivision(n int) bool {
	if n <= 1 {
		return false
	}
	if n <= 3 {
		return true
	}
	if n%2 == 0 || n%3 == 0 {
		return false
	}

	sqrtN := int(math.Floor(math.Sqrt(float64(n))))

	// curr is 6k-1 and curr+2 is 6k+1.
	for curr := 5; curr <= sqrtN; curr += 6 {
		if !divisibilityCheck(curr, n) || !divisibilityCheck(curr+2, n) {
			return false
		}
	}

	return true
}

// ThreadedTrialDivision checks if n is prime by splitting odd divisor checks across x threads.
// Returns whether n is prime and the ID of the thread that finished last (-1 if rejected before spawning).
func ThreadedTrialDivision(n int, x int) (bool, int) {
	// With no threads nothing would be tested, and every odd n would be reported prime.
	if x < 1 || x > math.MaxInt32 {
		panic(fmt.Sprintf("ThreadedTrialDivision: thread count must be between 1 and %d, got %d", math.MaxInt32, x))
	}
	if n <= 1 {
		return false, -1
	}
	if n != 2 && n%2 == 0 {
		return false, -1
	}

	sqrtN := int(math.Floor(math.Sqrt(float64(n))))

	var wg sync.WaitGroup
	var isPrime atomic.Bool
	isPrime.Store(true)

	var finished atomic.Int32
	lastID := -1

	for i := range x {
		wg.Add(1)

		startAt := 3 + (i * 2)

		go func(workerID, curr int) {
			defer wg.Done()
			defer func() {
				if finished.Add(1) == int32(x) {
					lastID = workerID
				}
			}()

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
		}(i, startAt)
	}

	wg.Wait()

	return isPrime.Load(), lastID
}

func divisibilityCheck(curr int, n int) bool {
	if n%curr == 0 {
		return false
	}
	return true
}
