package main

import (
	"log"
	"slices"

	options "github.com/zrygan/prime_number_search/options"
	"github.com/zrygan/prime_number_search/prime"
)

func chunkPrintNow(cfg options.Config) []int {
	return prime.ByRange(cfg, options.Now)
}

func chunkPrintLater(cfg options.Config) []int {
	return prime.ByRange(cfg, options.Later)
}

func linearPrintNow(cfg options.Config) []int {
	return prime.ByDivisibility(cfg, options.Now)
}

func linearPrintLater(cfg options.Config) []int {
	return prime.ByDivisibility(cfg, options.Later)
}

func main() {
	cfg := options.ReadConfig("config")

	// run the four variants and check if the output is the same
	// todo: run performance benchmarks
	variantCN := chunkPrintNow(cfg)
	variantCL := chunkPrintLater(cfg)
	if !slices.Equal(variantCN, variantCL) {
		log.Panic("Result mismatch")
	}

	variantLN := linearPrintNow(cfg)
	variantLL := linearPrintLater(cfg)
	if !slices.Equal(variantCL, variantLN) || !slices.Equal(variantLN, variantLL) {
		log.Panic("Result mismatch")
	}
}
