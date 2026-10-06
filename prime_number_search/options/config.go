package options

import (
	"log"
	"os"
	"strconv"
	"strings"
)

type Config struct {
	X int
	Y int
}

// ReadConfig reads a config file containing the thread count (x) and upper bound (y).
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
