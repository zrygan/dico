package options

import "fmt"

type PrintConfig int

const (
	Now PrintConfig = iota
	Later
)

// Validate checks that p is one of the defined print modes.
func (p PrintConfig) Validate() error {
	if p != Now && p != Later {
		return fmt.Errorf("invalid print mode %d (must be Now or Later)", int(p))
	}
	return nil
}
