package util

import (
	"errors"
	"fmt"
)

type IntStack struct {
	items []int
}

func (is *IntStack) Push(n int) {
	is.items = append(is.items, n)
}

func (is *IntStack) Pop() (int, error) {
	if is.IsEmpty() {
		return 0, errors.New("IntStack is empty")
	}

	i := len(is.items) - 1
	n := is.items[i]
	is.items = is.items[:i]

	return n, nil
}

func (is *IntStack) IsEmpty() bool {
	return len(is.items) == 0
}

// IntStackRange creates an IntStack with numbers from n up to m-1.
// The range must be non-empty and non-negative.
func IntStackRange(n int, m int) (*IntStack, error) {
	if n < 0 || m <= n {
		return nil, fmt.Errorf("invalid IntStackRange [%d, %d): need 0 <= n < m", n, m)
	}

	is := &IntStack{items: make([]int, 0, m-n)}

	for i := n; i < m; i++ {
		is.Push(i)
	}

	return is, nil
}
