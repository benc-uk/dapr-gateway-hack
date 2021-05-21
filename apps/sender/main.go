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
		appId = "receiver"
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
	log.Printf("### Will use %s as the Dapr port\n", daprPort)

	// Construct Dapr URL to invoke remote app and method
	url := fmt.Sprintf("http://localhost:%s/v1.0/invoke/%s/method/%s", daprPort, appId, method)
	log.Printf("### Will make HTTP requests every %d seconds to %s\n", intervalInt, url)

	for {
		time.Sleep(time.Duration(intervalInt) * time.Second)
		log.Printf("### Making HTTP call to %s\n", url)

		// Only makes GET requests but that's good enough :)
		resp, err := http.Get(url)
		if err != nil {
			log.Printf("### ERROR %v", err)
			continue
		}
		log.Printf("### Got response %s", resp.Status)
	}
}
