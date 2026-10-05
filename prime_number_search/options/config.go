package options

import (
	"log"
	"os"
	"strconv"
	"strings"
)

// Config represents the configuration settings for the search operation.
type Config struct {
	X int // X specifies the number of threads to use.
	Y int // Y sets the search upper bound, defining the search space as [0, y].
}

// ReadConfig reads a configuration file specified by file_name and extracts two
// space-separated integers representing the number of threads (x) and the
// search upper bound (y). It returns a Config struct containing these values.
//
// If the file cannot be read, has fewer than two fields, or contains invalid
// integers, the function will panic and halt the program.
func ReadConfig(file_name string) Config {
	content, err := os.ReadFile(file_name)
	if err != nil {
		log.Panicf("Failed to read file: %s. Has error: %s", file_name, err)
	}

	cont_arr := strings.Fields(string(content))
	if len(cont_arr) < 2 {
		log.Panic("Expected at least two fields in the config (for x and y).")
	}

	var opt Config

	if opt.X, err = strconv.Atoi(cont_arr[0]); err != nil {
		log.Panicf("Failed to parse x (threads): %s", err)
	}

	if opt.Y, err = strconv.Atoi(cont_arr[1]); err != nil {
		log.Panicf("Failed to parse y (search bound): %s", err)
	}

	return opt
}
