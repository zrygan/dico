package util

import (
	"log"
	"time"
)

// TrackRuntime executes a function and logs start, end, and total runtime duration.
func TrackRuntime(taskName string, fn func()) time.Duration {
	startTime := time.Now()
	log.Printf("[%s] Started at: %s", taskName, startTime.Format(time.RFC3339Nano))

	fn()

	endTime := time.Now()
	elapsed := endTime.Sub(startTime)
	log.Printf("[%s] Finished at: %s", taskName, endTime.Format(time.RFC3339Nano))
	log.Printf("[%s] Total runtime: %v", taskName, elapsed)

	return elapsed
}
