package main

import (
	"encoding/json"
	"fmt"
	"html"
	"log"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/echo", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("\n### HTTP request '%s' received from '%s' for path '%s' to host '%s'", r.Method, r.RemoteAddr, r.RequestURI, r.Host)
		headerPretty, err := json.MarshalIndent(r.Header, "", "  ")
		if err != nil {
			fmt.Println("error:", err)
		}

		log.Printf("### - Headers %s\n", string(headerPretty))
		fmt.Fprintf(w, "HTTP req received from, %q", html.EscapeString(r.URL.Path))
	})

	log.Println(fmt.Sprintf("### Server started on port %s", port))
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port), nil))
}
