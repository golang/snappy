package main

import (
	"flag"
	"fmt"
	"io"
	"os"

	"github.com/golang/snappy"
)

var (
	enc = flag.Bool("e", false, "encode")
	dec = flag.Bool("d", false, "decode")
)

func run() int {
	flag.Parse()
	if *enc == *dec {
		fmt.Fprintf(os.Stderr, "exactly one of -d or -e must be given")
		return 1
	}

	// Encode or decode stdin, and write to stdout.
	var err error
	if *enc {
		_, err = io.Copy(snappy.NewWriter(os.Stdout), os.Stdin)
	} else {
		_, err = io.Copy(os.Stdout, snappy.NewReader(os.Stdin))
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, err.Error())
		return 1
	}
	return 0
}

func main() {
	os.Exit(run())
}
