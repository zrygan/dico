package main

import (
	"log"

	"github.com/zrygan/group_synchronization/lfg"
	"github.com/zrygan/group_synchronization/options"
	"github.com/zrygan/group_synchronization/util"
)

func main() {
	cfg, err := options.ReadConfig("config")
	if err != nil {
		log.Fatal(err)
	}

	var runErr error
	util.TrackRuntime("LFG Dungeon Queue", func() {
		_, runErr = lfg.Run(cfg)
	})
	if runErr != nil {
		log.Fatal(runErr)
	}
}
