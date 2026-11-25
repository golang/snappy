//go:build gc && !appengine && !noasm && go1.26 && !go1.27
// +build gc,!appengine,!noasm,go1.26,!go1.27

package snappy

// internal/cpu.RISCV64 in Go 1.26 starts with a 64-byte CacheLinePad and
// HasFastMisaligned, followed by HasV. Recheck the layout for new toolchains.
const offsetRISCV64HasV = 64 + 1
