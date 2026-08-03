// Example Go HTTP service for httpd-next (served behind Nginx proxy_pass).
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime"
)

func main() {
	addr := envOr("GO_APP_ADDR", "127.0.0.1:8080")

	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprintf(
			w,
			`<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>httpd-next go</title></head><body><h1>Go is working</h1><p>%s</p><p>Path: %s</p></body></html>`,
			runtime.Version(),
			r.URL.Path,
		)
	})
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte("ok\n"))
	})

	log.Printf("go app listening on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatal(err)
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
