package prime

import (
	"log"
	"math"
	"sync"

	"github.com/zrygan/prime_number_search/options"
	"github.com/zrygan/prime_number_search/util"
)

// The smallest prime, so the search space is [searchStart, cfg.Y].
const searchStart = 2

// Scheme 1 (coarse-grained): straight division of the search range
// [2, cfg.Y] into chunks across cfg.X threads. Each thread tests the numbers
// in its own chunk sequentially.
func ByRange(cfg options.Config, printType options.PrintConfig) {
	limit := cfg.Y + 1
	scope := int(math.Ceil(float64(limit-searchStart) / float64(cfg.X)))

	var wg sync.WaitGroup
	var found []int
	var mu sync.Mutex

	for i := range cfg.X {
		bot := searchStart + i*scope
		if bot >= limit {
			break
		}
		top := min(bot+scope, limit)

		wg.Add(1)
		go func(workerID, minS, maxS int) {
			defer wg.Done()

			// Each worker has its own blob
			isr, err := util.IntStackRange(minS, maxS)
			if err != nil {
				log.Panic(err)
			}

			for !isr.IsEmpty() {
				if curr, err := isr.Pop(); err == nil {
					if TrialDivision(curr) {
						if printType == options.Now {
							log.Printf("[Thread %d] Found prime: %d", workerID, curr)
						} else {
							mu.Lock()
							found = append(found, curr)
							mu.Unlock()
						}
					}
				}
			}
		}(i, bot, top)
	}

	wg.Wait()

	if printType == options.Later {
		log.Printf("All threads completed. Found %d primes: %v", len(found), found)
	}
}

// Scheme 2 (fine-grained): linear search across the numbers [2, cfg.Y],
// where the divisors of each number are split across cfg.X threads.
func ByDivisors(cfg options.Config, printType options.PrintConfig) {
	var found []int
	for i := searchStart; i <= cfg.Y; i++ {
		if isPrime, workerID := ThreadedTrialDivision(i, cfg.X); isPrime {
			if printType == options.Now {
				log.Printf("[Thread %d] Found prime: %d", workerID, i)
			} else {
				found = append(found, i)
			}
		}
	}

	if printType == options.Later {
		log.Printf("All threads completed. Found %d primes: %v", len(found), found)
	}
}
