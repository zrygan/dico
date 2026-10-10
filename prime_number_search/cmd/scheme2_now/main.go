package main

import (
	"log"

	"github.com/zrygan/prime_number_search/options"
	"github.com/zrygan/prime_number_search/prime"
	"github.com/zrygan/prime_number_search/util"
)

func main() {
	cfg, err := options.ReadConfig("config")
	if err != nil {
		log.Fatal(err)
	}

	util.TrackRuntime("Scheme 2 (Divisor Split - Print Now)", func() {
		prime.ByDivisors(cfg, options.Now)
	})
}
