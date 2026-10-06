package prime

import (
	"log"
	"math"
	"sync"

	"github.com/zrygan/prime_number_search/options"
	"github.com/zrygan/prime_number_search/util"
)

const searchStart = 2

// ByRange divides the search range [2, cfg.Y] evenly across cfg.X threads.
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

// ByDivisors tests numbers from 2 to cfg.Y one by one, dividing candidate divisors across cfg.X threads.
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
