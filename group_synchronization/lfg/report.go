package lfg

import (
	"fmt"
	"os"
	"text/tabwriter"
	"time"

	"github.com/zrygan/group_synchronization/options"
)

// printQueue prints the inputs, the number of parties formed and the
// players left in the queue.
func printQueue(cfg options.Config, parties int, left Leftover) {
	fmt.Printf("Queue: %d tanks, %d healers, %d DPS | %d instances | clear time %ds to %ds\n",
		cfg.Tanks, cfg.Healers, cfg.DPS, cfg.Instances, cfg.MinClear, cfg.MaxClear)
	fmt.Printf("Formed %d parties. Left in queue: %d tanks, %d healers, %d DPS\n\n",
		parties, left.Tanks, left.Healers, left.DPS)
}

// printEvent prints one timestamped event line. elapsed is the time since the
// queue started.
func printEvent(elapsed time.Duration, format string, args ...any) {
	fmt.Printf("[%6.2fs] %s\n", elapsed.Seconds(), fmt.Sprintf(format, args...))
}

// printBoard prints the status of every instance. Callers that share the
// board must hold its lock.
func printBoard(instances []Instance) {
	for _, inst := range instances {
		if inst.Status == Active {
			fmt.Printf("          Instance %d: %v (party %d)\n", inst.ID, inst.Status, inst.PartyID)
		} else {
			fmt.Printf("          Instance %d: %v\n", inst.ID, inst.Status)
		}
	}
	fmt.Println()
}

// printSummary prints how many parties each instance served and the total
// time it was active, followed by the totals for all instances.
func printSummary(instances []Instance) {
	fmt.Println("Summary")

	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
	fmt.Fprintln(w, "Instance\tParties served\tTime served")

	var served int
	var total time.Duration
	for _, inst := range instances {
		fmt.Fprintf(w, "%d\t%d\t%v\n", inst.ID, inst.Served, inst.TimeServed)
		served += inst.Served
		total += inst.TimeServed
	}

	fmt.Fprintf(w, "Total\t%d\t%v\n", served, total)
	w.Flush()
}
