package main

import (
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

func main() {
	url := os.Getenv("URL")
	if url == "" {
		log.Fatalln("URL env var must be set! I'm dead now")
	}
	interval := os.Getenv("INTERVAL")
	if interval == "" {
		interval = "5"
	}
	intervalInt, _ := strconv.Atoi(interval)

	for {
		time.Sleep(time.Duration(intervalInt) * time.Second)
		log.Printf("### Making HTTP call to %s\n", url)
		resp, err := http.Get(url)
		if err != nil {
			log.Printf("### ERROR %v", err)
			continue
		}
		log.Printf("### Got response %s", resp.Status)
	}
}
