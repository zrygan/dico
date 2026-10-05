package options

// PrintConfig specifies what type of printing procedure to use.
type PrintConfig int

const (
	// Now means that the thread prints immediately.
	Now PrintConfig = iota

	// Later means that all threads wait for each other.
	Later
)
