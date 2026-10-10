package prime

import (
	"log"

	"github.com/zrygan/prime_number_search/options"
)

// Sieve finds every prime in [2, cfg.Y] with a sequential sieve of Eratosthenes.
// It runs on a single thread and ignores cfg.X; it is the baseline for the threaded schemes.
func Sieve(cfg options.Config, printType options.PrintConfig) {
	mustValidate(cfg, printType)

	composite := make([]bool, cfg.Y+1)
	var found []int

	for i := searchStart; i <= cfg.Y; i++ {
		if composite[i] {
			continue
		}

		if printType == options.Now {
			log.Printf("[Thread 0] Found prime: %d", i)
		} else {
			found = append(found, i)
		}

		for j := i * i; j <= cfg.Y; j += i {
			composite[j] = true
		}
	}

	if printType == options.Later {
		log.Printf("All threads completed. Found %d primes: %v", len(found), found)
	}
}
