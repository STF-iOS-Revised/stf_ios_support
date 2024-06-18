package main

import (
	"fmt"
	"net/http"
)

func main() {
	fs := http.FileServer(http.Dir("./updates"))
	fmt.Println(http.ListenAndServe(":8022", fs))
}
