package prime

import "testing"

func TestTrialDivision(t *testing.T) {
	primesBelow30 := map[int]bool{
		2: true, 3: true, 5: true, 7: true, 11: true,
		13: true, 17: true, 19: true, 23: true, 29: true,
	}

	for n := 0; n <= 30; n++ {
		expected := primesBelow30[n]
		if got := TrialDivision(n); got != expected {
			t.Errorf("TrialDivision(%d) = %v; want %v", n, got, expected)
		}
		for threads := 1; threads <= 5; threads++ {
			if got := ThreadedTrialDivision(n, threads); got != expected {
				t.Errorf("ThreadedTrialDivision(%d, threads=%d) = %v; want %v", n, threads, got, expected)
			}
		}
	}

	// Test squares of primes and larger numbers
	composites := []int{49, 121, 169, 289, 361, 529, 841, 961, 1000}
	for _, n := range composites {
		if TrialDivision(n) {
			t.Errorf("TrialDivision(%d) = true; want false", n)
		}
		if ThreadedTrialDivision(n, 4) {
			t.Errorf("ThreadedTrialDivision(%d) = true; want false", n)
		}
	}

	primes := []int{31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 1009}
	for _, n := range primes {
		if !TrialDivision(n) {
			t.Errorf("TrialDivision(%d) = false; want true", n)
		}
		if !ThreadedTrialDivision(n, 4) {
			t.Errorf("ThreadedTrialDivision(%d) = false; want true", n)
		}
	}
}
