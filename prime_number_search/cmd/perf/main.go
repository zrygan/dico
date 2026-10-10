package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/zrygan/prime_number_search/options"
	"github.com/zrygan/prime_number_search/prime"
)

type scheme struct {
	name      string
	run       func(options.Config, options.PrintConfig)
	printType options.PrintConfig
}

var schemes = []scheme{
	{"range / now", prime.ByRange, options.Now},
	{"range / later", prime.ByRange, options.Later},
	{"range 6k+-1 / now", prime.ByRangeSixK, options.Now},
	{"range 6k+-1 / later", prime.ByRangeSixK, options.Later},
	{"divisors / now", prime.ByDivisors, options.Now},
	{"divisors / later", prime.ByDivisors, options.Later},
	{"divisors pool / now", prime.ByDivisorsPool, options.Now},
	{"divisors pool / later", prime.ByDivisorsPool, options.Later},
	{"sieve (sequential) / now", prime.Sieve, options.Now},
	{"sieve (sequential) / later", prime.Sieve, options.Later},
}

const childEnv = "PERF_CASE"

func main() {
	if c := os.Getenv(childEnv); c != "" {
		runCase(c)
		return
	}

	xs := flag.String("x", "1,4,15", "comma-separated thread counts")
	ys := flag.String("y", "1000,100000,1000000,10000000", "comma-separated search upper bounds")
	timeout := flag.Duration("timeout", 3*time.Second, "kill and skip a case after this long")
	flag.Parse()

	if *timeout <= 0 {
		log.Fatalf("invalid -timeout %v (must be > 0)", *timeout)
	}
	if flag.NArg() > 0 {
		log.Fatalf("unexpected arguments: %v", flag.Args())
	}

	threads := parseInts("-x", *xs, options.MinThreads, options.MaxThreads)
	bounds := parseInts("-y", *ys, options.MinBound, options.MaxBound)

	self, err := os.Executable()
	if err != nil {
		log.Fatal(err)
	}

	for _, x := range threads {
		fmt.Printf("\nX = %d threads\n", x)
		fmt.Printf("%-30s", "scheme")
		for _, y := range bounds {
			fmt.Printf(" %12s", "Y="+strconv.Itoa(y))
		}
		fmt.Println()

		for i, s := range schemes {
			fmt.Printf("%-30s", s.name)
			skipped := false

			for _, y := range bounds {
				if skipped {
					fmt.Printf(" %12s", "skipped")
					continue
				}

				elapsed, err := spawnCase(self, i, x, y, *timeout)
				switch {
				case errors.Is(err, context.DeadlineExceeded):
					fmt.Printf(" %12s", "> "+timeout.String())
					skipped = true
				case err != nil:
					fmt.Printf(" %12s", "error")
					fmt.Fprintf(os.Stderr, "\n%s x=%d y=%d: %v\n", s.name, x, y, err)
				default:
					fmt.Printf(" %12v", elapsed.Round(time.Microsecond))
				}
			}
			fmt.Println()
		}
	}
}

// Runs one case in a child process and returns the runtime it reports.
func spawnCase(self string, idx, x, y int, timeout time.Duration) (time.Duration, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, self)
	cmd.Env = append(os.Environ(), fmt.Sprintf("%s=%d %d %d", childEnv, idx, x, y))
	cmd.Stderr = os.Stderr

	out, err := cmd.Output()
	if ctx.Err() != nil {
		return 0, ctx.Err()
	}
	if err != nil {
		return 0, err
	}

	ns, err := strconv.ParseInt(strings.TrimSpace(string(out)), 10, 64)
	if err != nil {
		return 0, fmt.Errorf("bad child output %q", out)
	}
	return time.Duration(ns), nil
}

// Runs one case in this process and prints its runtime in nanoseconds.
func runCase(c string) {
	var idx, x, y int
	var extra string
	if n, _ := fmt.Sscan(c, &idx, &x, &y, &extra); n != 3 || idx < 0 || idx >= len(schemes) {
		log.Fatalf("invalid %s=%q", childEnv, c)
	}
	cfg := options.Config{X: x, Y: y}
	if err := cfg.Validate(); err != nil {
		log.Fatalf("invalid %s=%q: %v", childEnv, c, err)
	}

	devNull, err := os.OpenFile(os.DevNull, os.O_WRONLY, 0)
	if err != nil {
		log.Fatal(err)
	}
	defer devNull.Close()

	log.SetOutput(devNull)

	s := schemes[idx]
	start := time.Now()
	s.run(cfg, s.printType)
	fmt.Println(time.Since(start).Nanoseconds())
}

func parseInts(flagName, s string, minimum, maximum int) []int {
	var nums []int
	for _, f := range strings.Split(s, ",") {
		n, err := strconv.Atoi(strings.TrimSpace(f))
		if err != nil || n < minimum || n > maximum {
			log.Fatalf("invalid %s value %q (must be an integer from %d to %d)", flagName, f, minimum, maximum)
		}
		nums = append(nums, n)
	}
	return nums
}
