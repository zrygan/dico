package prime

import (
	"log"

	options "github.com/zrygan/prime_number_search/options"
)

// ByDivisibility implements Scheme 2:
// Linear search across candidate numbers [0, cfg.Y],
// with threaded divisibility testing for each number using cfg.X threads.
func ByDivisibility(cfg options.Config, printType options.PrintConfig) []int {
	var found []int
	for i := range cfg.Y + 1 {
		if ThreadedTrialDivision(i, cfg.X) {
			found = append(found, i)
			if printType == options.Now {
				log.Printf("Found prime: %d", i)
			}
		}
	}

	if printType == options.Later {
		log.Printf("All threads completed. Found %d primes: %v", len(found), found)
	}

	return found
}
