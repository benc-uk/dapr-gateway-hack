package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

func main() {
	appId := os.Getenv("REMOTE_APP_ID")
	if appId == "" {
		log.Fatalln("REMOTE_APP_ID env var must be set! I'm dead now")
	}
	method := os.Getenv("REMOTE_METHOD")
	if method == "" {
		method = "echo"
	}
	interval := os.Getenv("INTERVAL")
	if interval == "" {
		interval = "5"
	}
	intervalInt, _ := strconv.Atoi(interval)

	daprPort := os.Getenv("DAPR_HTTP_PORT")
	if daprPort == "" {
		daprPort = "3500"
	}
	log.Println("### Found DAPR PORT: ", daprPort)

	url := fmt.Sprintf("http://localhost:%s/v1.0/invoke/%s/method/%s", daprPort, appId, method)
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
