package lfg

import "github.com/zrygan/group_synchronization/options"

// Constants for number of players needed per party.
const (
	TanksPerParty   = 1
	HealersPerParty = 1
	DPSPerParty     = 3
)

// A Party is a group of people which satisfy the constants above.
// IDs start at 1 and follow queue order.
type Party struct {
	ID int
}

// The  Leftover counter which keeps track of the number of  players per
// role that could not fill a full party.
type Leftover struct {
	Tanks   int
	Healers int
	DPS     int
}

// FormParties groups the queued players into as many full parties as
// possible. Then compute those that do not have a group yet. This
// function also does not pre-emptively groups "non-parties together".
// This means that if there are only 4 players, do not group those 4
// and wait for the missing player.
func FormParties(cfg options.Config) ([]Party, Leftover) {
	maxFromTanks := cfg.Tanks / TanksPerParty
	maxFromHealers := cfg.Healers / HealersPerParty
	maxFromDPS := cfg.DPS / DPSPerParty

	maxParties := min(maxFromTanks, maxFromHealers, maxFromDPS)

	parties := make([]Party, maxParties)
	for i := range parties {
		parties[i] = Party{ID: i + 1}
	}

	left := Leftover{
		Tanks:   cfg.Tanks - maxParties*TanksPerParty,
		Healers: cfg.Healers - maxParties*HealersPerParty,
		DPS:     cfg.DPS - maxParties*DPSPerParty,
	}

	return parties, left
}
