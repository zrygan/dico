package main

import (
	"github.com/zrygan/prime_number_search/options"
	"github.com/zrygan/prime_number_search/prime"
	"github.com/zrygan/prime_number_search/util"
)

func main() {
	cfg := options.ReadConfig("config")

	util.TrackRuntime("Scheme 1 (Range Division - Print Now)", func() {
		prime.ByRange(cfg, options.Now)
	})
}
