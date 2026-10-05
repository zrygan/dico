package util

import "errors"

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

// IntStackRange returns a populated IntStack which contains
// values within the range [n,m). n and m cannot be equal and must be
// positive numbers.
func IntStackRange(n int, m int) (*IntStack, error) {
	if n < 0 || m < 0 || n == m {
		return nil, errors.New("Range for IntStackRange is invalid.")
	}

	is := &IntStack{}

	for i := n; i < m; i++ {
		is.Push(i)
	}

	return is, nil
}
