package prime

import (
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

// ThreadedTrialDivision checks if n is prime by splitting odd divisor checks across x threads.
// Returns whether n is prime and the ID of the thread that finished last (-1 if rejected before spawning).
func ThreadedTrialDivision(n int, x int) (bool, int) {
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
