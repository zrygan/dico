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

	util.TrackRuntime("Scheme 1 (Range Division - Print Later)", func() {
		prime.ByRange(cfg, options.Later)
	})
}
