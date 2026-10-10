package prime

import (
	"fmt"
	"math"
	"sync/atomic"
)

// DivisorPool is a fixed set of x worker threads that split the odd divisor checks of a
// number between them, like ThreadedTrialDivision. The workers are started once and reused
// for every number, instead of being spawned and joined for each one.
type DivisorPool struct {
	x       int
	jobs    []chan int // jobs[i] sends the number to test to worker i
	done    chan int   // workers send their ID here once they finish a number
	isPrime atomic.Bool
}

// NewDivisorPool starts x worker threads. Call Close to stop them.
func NewDivisorPool(x int) *DivisorPool {
	// With no threads nothing would be tested, and every odd n would be reported prime.
	if x < 1 {
		panic(fmt.Sprintf("NewDivisorPool: thread count must be at least 1, got %d", x))
	}

	p := &DivisorPool{
		x:    x,
		jobs: make([]chan int, x),
		done: make(chan int, x),
	}

	for i := range x {
		p.jobs[i] = make(chan int, 1)
		go p.worker(i)
	}

	return p
}

// worker i tests the odd divisors 3+2i, 3+2i+2x, 3+2i+4x, ... of every number it receives.
func (p *DivisorPool) worker(workerID int) {
	move := p.x * 2

	for n := range p.jobs[workerID] {
		sqrtN := int(math.Floor(math.Sqrt(float64(n))))

		for curr := 3 + workerID*2; curr <= sqrtN; curr += move {
			if !p.isPrime.Load() {
				break
			}

			if !divisibilityCheck(curr, n) {
				p.isPrime.Store(false)
				break
			}
		}

		p.done <- workerID
	}
}

// Test checks if n is prime using the pool's workers.
// Returns whether n is prime and the ID of the thread that finished last (-1 if rejected before dispatching).
// Test must not be called concurrently.
func (p *DivisorPool) Test(n int) (bool, int) {
	if n <= 1 {
		return false, -1
	}
	if n != 2 && n%2 == 0 {
		return false, -1
	}

	// Reset before dispatching; the channel sends make this visible to the workers.
	p.isPrime.Store(true)

	for _, job := range p.jobs {
		job <- n
	}

	lastID := -1
	for range p.x {
		lastID = <-p.done
	}

	return p.isPrime.Load(), lastID
}

// Close stops the workers. The pool must not be used afterwards.
func (p *DivisorPool) Close() {
	for _, job := range p.jobs {
		close(job)
	}
}
