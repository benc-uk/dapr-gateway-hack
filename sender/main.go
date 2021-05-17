package main

import (
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	url := os.Getenv("URL")
	if url == "" {
		log.Fatalln("URL env var must be set! I'm dead now")
	}

	for {
		time.Sleep(2 * time.Second)
		log.Printf("### Making HTTP call to %s\n", url)
		resp, err := http.Get(url)
		if err != nil {
			log.Printf("### ERROR %v", err)
			continue
		}
		log.Printf("### Got response %s", resp.Status)
	}
}
