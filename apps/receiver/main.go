package main

import (
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"os"
	"strconv"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	httpPath := os.Getenv("HTTP_PATH")
	if httpPath == "" {
		httpPath = "/echo"
	}
	if httpPath[0] != '/' {
		log.Fatalln("### ERROR HTTP_PATH must start with a slash")
	}

	dumpEnv := os.Getenv("DUMP")
	dump, _ := strconv.ParseBool(dumpEnv)

	http.HandleFunc(httpPath, func(w http.ResponseWriter, r *http.Request) {
		log.Printf("### HTTP request '%s' received from '%s' for path '%s' to host '%s'", r.Method, r.RemoteAddr, r.RequestURI, r.Host)

		if dump {
			dumpData, err := httputil.DumpRequest(r, true)
			if err != nil {
				log.Printf("### ERROR dumping request failed %v", err)
			}
			fmt.Printf("%s\n--- END OF HTTP DUMP ---\n", string(dumpData))
		}
	})

	log.Println(fmt.Sprintf("### Server started on port %s", port))
	log.Println(fmt.Sprintf("### Accepting HTTP requests at %s", httpPath))
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port), nil))
}
