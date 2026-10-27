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

// String returns "empty" or "active", the labels used in the instance status output.
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

// dungeon is the shared state of all instances of the dungeon. mu guards
// instances, and their status is printed while mu is held so updates never
// interleave.
type dungeon struct {
	mu        sync.Mutex
	instances []Instance
	start     time.Time
}

func newDungeon(n int) *dungeon {
	d := &dungeon{
		instances: make([]Instance, n),
		start:     time.Now(),
	}
	for i := range d.instances {
		d.instances[i].ID = i + 1
	}
	return d
}

// enter marks instance idx as active with party p inside.
func (d *dungeon) enter(idx int, p Party, clear time.Duration) {
	d.mu.Lock()
	defer d.mu.Unlock()

	inst := &d.instances[idx]
	inst.Status = Active
	inst.PartyID = p.ID

	printEvent(time.Since(d.start), "Party %d entered instance %d (clear time %v)", p.ID, inst.ID, clear)
	printDungeon(d.instances)
}

// leave marks instance idx as empty and adds the finished clear to its totals.
func (d *dungeon) leave(idx int, p Party, clear time.Duration) {
	d.mu.Lock()
	defer d.mu.Unlock()

	inst := &d.instances[idx]
	inst.Status = Empty
	inst.PartyID = 0
	inst.Served++
	inst.TimeServed += clear

	printEvent(time.Since(d.start), "Party %d cleared instance %d", p.ID, inst.ID)
	printDungeon(d.instances)
}

// snapshot returns a copy of every instance's current state.
func (d *dungeon) snapshot() []Instance {
	d.mu.Lock()
	defer d.mu.Unlock()

	return append([]Instance(nil), d.instances...)
}
