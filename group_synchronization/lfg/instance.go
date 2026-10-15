package lfg

import (
	"sync"
	"time"
)

// Status is the state of a dungeon instance.
type Status int

// Instance states.
const (
	Empty Status = iota
	Active
)

// String returns "empty" or "active", the labels used in the status board.
func (s Status) String() string {
	if s == Active {
		return "active"
	}
	return "empty"
}

// Instance is one dungeon slot and its running totals.
type Instance struct {
	ID         int           // 1-based instance number
	Status     Status        // Active while a party is inside
	PartyID    int           // party inside, 0 when empty
	Served     int           // parties that finished a clear here
	TimeServed time.Duration // sum of the clear times of those parties
}

// board is the shared state of all instances. mu guards instances, and the
// board is printed while mu is held so updates never interleave.
type board struct {
	mu        sync.Mutex
	instances []Instance
	start     time.Time
}

func newBoard(n int) *board {
	b := &board{
		instances: make([]Instance, n),
		start:     time.Now(),
	}
	for i := range b.instances {
		b.instances[i].ID = i + 1
	}
	return b
}

// enter marks instance idx as active with party p inside.
func (b *board) enter(idx int, p Party, clear time.Duration) {
	b.mu.Lock()
	defer b.mu.Unlock()

	inst := &b.instances[idx]
	inst.Status = Active
	inst.PartyID = p.ID

	printEvent(time.Since(b.start), "Party %d entered instance %d (clear time %v)", p.ID, inst.ID, clear)
	printBoard(b.instances)
}

// leave marks instance idx as empty and adds the finished clear to its totals.
func (b *board) leave(idx int, p Party, clear time.Duration) {
	b.mu.Lock()
	defer b.mu.Unlock()

	inst := &b.instances[idx]
	inst.Status = Empty
	inst.PartyID = 0
	inst.Served++
	inst.TimeServed += clear

	printEvent(time.Since(b.start), "Party %d cleared instance %d", p.ID, inst.ID)
	printBoard(b.instances)
}

// snapshot returns a copy of every instance's current state.
func (b *board) snapshot() []Instance {
	b.mu.Lock()
	defer b.mu.Unlock()

	return append([]Instance(nil), b.instances...)
}
