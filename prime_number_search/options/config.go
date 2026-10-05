package options

import (
	"log"
	"os"
	"strconv"
	"strings"
)

// Config represents the configuration settings for the search operation.
type Config struct {
	X         int         // X specifies the number of threads to use.
	Y         int         // Y sets the search upper bound, defining the search space as [0, y].
	PrintType PrintConfig // PrintType specifies the printing style ("now" or "later").
}

// ReadConfig reads a configuration file specified by file_name.
// It supports either key-value lines (e.g. "threads 15", "x 15", "max 500", "y 500", "print_type now")
// or whitespace-delimited fields (e.g. "15 500 now").
// It returns a Config struct containing these values.
func ReadConfig(file_name string) Config {
	content, err := os.ReadFile(file_name)
	if err != nil {
		log.Panicf("Failed to read file: %s. Has error: %s", file_name, err)
	}

	opt := Config{
		PrintType: Now, // default
	}

	lines := strings.Split(string(content), "\n")
	hasKeyValue := false

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.Fields(line)
		if len(parts) >= 2 {
			key := strings.ToLower(strings.TrimSuffix(parts[0], "="))
			val := parts[1]
			if strings.Contains(parts[0], "=") {
				sub := strings.SplitN(parts[0], "=", 2)
				key = strings.ToLower(sub[0])
				val = sub[1]
			}

			switch key {
			case "threads", "x":
				if opt.X, err = strconv.Atoi(val); err != nil {
					log.Panicf("Failed to parse x (threads): %s", err)
				}
				hasKeyValue = true
			case "max", "y", "bound":
				if opt.Y, err = strconv.Atoi(val); err != nil {
					log.Panicf("Failed to parse y (search bound): %s", err)
				}
				hasKeyValue = true
			case "print_type", "printtype", "print":
				hasKeyValue = true
				switch strings.ToLower(val) {
				case "now":
					opt.PrintType = Now
				case "later":
					opt.PrintType = Later
				default:
					log.Panicf("Invalid print_type '%s': must be 'now' or 'later'", val)
				}
			}
		} else if len(parts) == 1 {
			// Single token line
		}
	}

	// Positional fallback for X and Y if not specified as key-values
	if opt.X == 0 || opt.Y == 0 {
		var posFields []string
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if line == "" || strings.HasPrefix(line, "#") {
				continue
			}
			parts := strings.Fields(line)
			if len(parts) > 0 {
				firstLower := strings.ToLower(parts[0])
				if firstLower == "print_type" || firstLower == "printtype" || firstLower == "print" || strings.HasPrefix(firstLower, "print_type=") {
					continue
				}
				posFields = append(posFields, parts...)
			}
		}

		if len(posFields) >= 2 {
			if opt.X == 0 {
				if opt.X, err = strconv.Atoi(posFields[0]); err != nil {
					log.Panicf("Failed to parse x (threads): %s", err)
				}
			}
			if opt.Y == 0 {
				if opt.Y, err = strconv.Atoi(posFields[1]); err != nil {
					log.Panicf("Failed to parse y (search bound): %s", err)
				}
			}
			if !hasKeyValue && len(posFields) >= 3 {
				switch strings.ToLower(posFields[2]) {
				case "now":
					opt.PrintType = Now
				case "later":
					opt.PrintType = Later
				default:
					log.Panicf("Invalid print_type '%s': must be 'now' or 'later'", posFields[2])
				}
			}
		} else if !hasKeyValue {
			log.Panic("Expected at least two fields in the config (for x and y).")
		}
	}

	return opt
}
