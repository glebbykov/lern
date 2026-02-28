package main

import (
	"fmt"
	"net/http"
)

func healthz(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func main() {
	http.HandleFunc("/healthz", healthz)
	fmt.Println("listening on :8084")
	_ = http.ListenAndServe(":8084", nil)
}
