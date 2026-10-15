package lfg

import (
	"math/rand/v2"
	"sync"
	"time"

	"github.com/zrygan/group_synchronization/options"
)

// Run forms parties from the queued players and runs them through
// cfg.Instances dungeon instances, printing the status board on every change
// and a summary at the end. It returns the final state of every instance.
//
// All parties are put on one buffered channel, in queue order, before any
// instance starts (every player arrives at the same time). Each instance is a
// goroutine that takes the next party, clears the dungeon and repeats until
// the channel is empty, so:
//   - at most cfg.Instances parties are ever inside a dungeon,
//   - parties leave the channel in FIFO order and clear times are bounded,
//     so every party is served (no starvation),
//   - instances never wait on each other or hold a lock while waiting,
//     so there is no circular wait (no deadlock).
func Run(cfg options.Config) ([]Instance, error) {
	if err := cfg.Validate(); err != nil {
		return nil, err
	}

	parties, left := FormParties(cfg)
	printQueue(cfg, len(parties), left)

	queue := make(chan Party, len(parties))
	for _, p := range parties {
		queue <- p
	}
	close(queue)

	b := newBoard(cfg.Instances)
	printBoard(b.instances)

	var wg sync.WaitGroup
	for i := range cfg.Instances {
		wg.Add(1)
		go func(idx int) {
			defer wg.Done()
			b.serve(idx, queue, cfg.MinClear, cfg.MaxClear)
		}(i)
	}

	wg.Wait()

	final := b.snapshot()
	printSummary(final)

	return final, nil
}

// serve runs instance idx: it takes parties from queue one at a time and
// keeps each inside for a random clear time in [t1, t2] seconds.
func (b *board) serve(idx int, queue <-chan Party, t1, t2 int) {
	for p := range queue {
		clear := clearTime(t1, t2)

		b.enter(idx, p, clear)
		time.Sleep(clear)
		b.leave(idx, p, clear)
	}
}

// clearTime picks a whole number of seconds uniformly from [t1, t2].
func clearTime(t1, t2 int) time.Duration {
	return time.Duration(t1+rand.IntN(t2-t1+1)) * time.Second
}
