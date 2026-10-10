package options

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Limits for the config values.
const (
	MinThreads = 1
	MaxThreads = 1 << 16

	MinBound = 0
	MaxBound = 100_000_000

	maxConfigSize = 1 << 10
)

type Config struct {
	X int
	Y int
}

// Validate checks that x and y are within their allowed ranges.
func (c Config) Validate() error {
	if c.X < MinThreads || c.X > MaxThreads {
		return fmt.Errorf("x (threads) must be between %d and %d, got %d", MinThreads, MaxThreads, c.X)
	}
	if c.Y < MinBound || c.Y > MaxBound {
		return fmt.Errorf("y (search bound) must be between %d and %d, got %d", MinBound, MaxBound, c.Y)
	}
	return nil
}

// ReadConfig reads a config file containing exactly two integers: the thread count (x) and upper bound (y).
func ReadConfig(file_name string) (Config, error) {
	info, err := os.Stat(file_name)
	if err != nil {
		return Config{}, fmt.Errorf("failed to read config %q: %w", file_name, err)
	}
	if !info.Mode().IsRegular() {
		return Config{}, fmt.Errorf("config %q is not a regular file", file_name)
	}
	if info.Size() > maxConfigSize {
		return Config{}, fmt.Errorf("config %q is too large (%d bytes, max %d)", file_name, info.Size(), maxConfigSize)
	}

	content, err := os.ReadFile(file_name)
	if err != nil {
		return Config{}, fmt.Errorf("failed to read config %q: %w", file_name, err)
	}

	cont_arr := strings.Fields(string(content))
	if len(cont_arr) != 2 {
		return Config{}, fmt.Errorf("config %q must contain exactly two integers (x and y), found %d field(s)", file_name, len(cont_arr))
	}

	var opt Config

	if opt.X, err = parseInt("x (threads)", cont_arr[0]); err != nil {
		return Config{}, err
	}

	if opt.Y, err = parseInt("y (search bound)", cont_arr[1]); err != nil {
		return Config{}, err
	}

	if err := opt.Validate(); err != nil {
		return Config{}, err
	}

	return opt, nil
}

func parseInt(name, s string) (int, error) {
	n, err := strconv.Atoi(s)
	if errors.Is(err, strconv.ErrRange) {
		return 0, fmt.Errorf("%s is out of range: %q", name, s)
	}
	if err != nil {
		return 0, fmt.Errorf("%s must be a whole number, got %q", name, s)
	}
	return n, nil
}
