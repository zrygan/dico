// Package options reads and validates the queue configuration.
package options

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Limits for the config values. Clear times are in seconds.
const (
	MinInstances = 1
	MaxInstances = 1 << 10

	MinPlayers = 0
	MaxPlayers = 1 << 20

	MinClearTime = 0
	MaxClearTime = 15

	maxConfigSize = 1 << 10
)

// Config holds the queue inputs: n instances, the players per role, and
// the clear time bounds [t1, t2] in seconds.
type Config struct {
	Instances int // n
	Tanks     int // t
	Healers   int // h
	DPS       int // d
	MinClear  int // t1
	MaxClear  int // t2
}

// Validate checks that every value is within its allowed range and that t1 <= t2.
func (c Config) Validate() error {
	if c.Instances < MinInstances || c.Instances > MaxInstances {
		return fmt.Errorf("n (instances) must be between %d and %d, got %d", MinInstances, MaxInstances, c.Instances)
	}

	players := []struct {
		name  string
		count int
	}{
		{"t (tanks)", c.Tanks},
		{"h (healers)", c.Healers},
		{"d (DPS)", c.DPS},
	}
	for _, p := range players {
		if p.count < MinPlayers || p.count > MaxPlayers {
			return fmt.Errorf("%s must be between %d and %d, got %d", p.name, MinPlayers, MaxPlayers, p.count)
		}
	}

	if c.MinClear < MinClearTime || c.MinClear > MaxClearTime {
		return fmt.Errorf("t1 (min clear time) must be between %d and %d, got %d", MinClearTime, MaxClearTime, c.MinClear)
	}
	if c.MaxClear < MinClearTime || c.MaxClear > MaxClearTime {
		return fmt.Errorf("t2 (max clear time) must be between %d and %d, got %d", MinClearTime, MaxClearTime, c.MaxClear)
	}
	if c.MinClear > c.MaxClear {
		return fmt.Errorf("t1 (%d) must not be greater than t2 (%d)", c.MinClear, c.MaxClear)
	}

	return nil
}

// ReadConfig reads a config file containing exactly six integers: n t h d t1 t2.
func ReadConfig(fileName string) (Config, error) {
	info, err := os.Stat(fileName)
	if err != nil {
		return Config{}, fmt.Errorf("failed to read config %q: %w", fileName, err)
	}
	if !info.Mode().IsRegular() {
		return Config{}, fmt.Errorf("config %q is not a regular file", fileName)
	}
	if info.Size() > maxConfigSize {
		return Config{}, fmt.Errorf("config %q is too large (%d bytes, max %d)", fileName, info.Size(), maxConfigSize)
	}

	content, err := os.ReadFile(fileName)
	if err != nil {
		return Config{}, fmt.Errorf("failed to read config %q: %w", fileName, err)
	}

	fields := strings.Fields(string(content))
	if len(fields) != 6 {
		return Config{}, fmt.Errorf("config %q must contain exactly six integers (n t h d t1 t2), found %d field(s)", fileName, len(fields))
	}

	var cfg Config
	targets := []struct {
		name string
		dst  *int
	}{
		{"n (instances)", &cfg.Instances},
		{"t (tanks)", &cfg.Tanks},
		{"h (healers)", &cfg.Healers},
		{"d (DPS)", &cfg.DPS},
		{"t1 (min clear time)", &cfg.MinClear},
		{"t2 (max clear time)", &cfg.MaxClear},
	}
	for i, t := range targets {
		if *t.dst, err = parseInt(t.name, fields[i]); err != nil {
			return Config{}, err
		}
	}

	if err := cfg.Validate(); err != nil {
		return Config{}, err
	}

	return cfg, nil
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
