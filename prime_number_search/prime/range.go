package prime

import (
	"log"
	"math"
	"slices"
	"sync"

	options "github.com/zrygan/prime_number_search/options"
)

// ByRange implements Scheme 1:
// Straight division of the search range [0, cfg.Y] into chunks across cfg.X threads.
func ByRange(cfg options.Config, printType options.PrintConfig) []int {
	limit := cfg.Y + 1
	scope := int(math.Ceil(float64(limit) / float64(cfg.X)))

	var wg sync.WaitGroup
	var found []int
	var mu sync.Mutex

	for i := range cfg.X {
		bot := i * scope
		if bot >= limit {
			break
		}
		top := min(bot+scope, limit)

		wg.Add(1)
		go func(workerID, minS, maxS int) {
			defer wg.Done()

			// Each worker has its own blob
			isr, err := IntStackRange(minS, maxS)
			if err != nil {
				log.Panic(err)
			}

			for !isr.IsEmpty() {
				if curr, err := isr.Pop(); err == nil {
					if TrialDivision(curr) {
						mu.Lock()
						found = append(found, curr)
						if printType == options.Now {
							log.Printf("[Thread %d] Found prime: %d", workerID, curr)
						}
						mu.Unlock()
					}
				}
			}
		}(i, bot, top)
	}

	wg.Wait()

	slices.Sort(found)
	if printType == options.Later {
		log.Printf("All threads completed. Found %d primes: %v", len(found), found)
	}
	return found
}
