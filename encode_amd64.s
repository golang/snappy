// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build !appengine
// +build gc
// +build !noasm

#include "textflag.h"

// The asm code generally follows the pure Go code in encode_other.go, except
// where marked with a "!!!".

// func extendMatch(src []byte, i, j int) int
//
// All local variables fit into registers. The register allocation:
//	- CX	&src[0]
//	- DX	&src[len(src)]
//	- SI	&src[i]
//	- DI	&src[j]
//	- R9	&src[len(src) - 8]
TEXT ·extendMatch(SB), NOSPLIT, $0-48
	MOVQ src_base+0(FP), CX
	MOVQ src_len+8(FP), DX
	MOVQ i+24(FP), SI
	MOVQ j+32(FP), DI
	ADDQ CX, DX
	ADDQ CX, SI
	ADDQ CX, DI
	MOVQ DX, R9
	SUBQ $8, R9

cmp8:
	// As long as we are 8 or more bytes before the end of src, we can load and
	// compare 8 bytes at a time. If those 8 bytes are equal, repeat.
	CMPQ DI, R9
	JA   cmp1
	MOVQ (SI), AX
	MOVQ (DI), BX
	CMPQ AX, BX
	JNE  bsf
	ADDQ $8, SI
	ADDQ $8, DI
	JMP  cmp8

bsf:
	// If those 8 bytes were not equal, XOR the two 8 byte values, and return
	// the index of the first byte that differs. The BSF instruction finds the
	// least significant 1 bit, the amd64 architecture is little-endian, and
	// the shift by 3 converts a bit index to a byte index.
	XORQ AX, BX
	BSFQ BX, BX
	SHRQ $3, BX
	ADDQ BX, DI

	// Convert from &src[ret] to ret.
	SUBQ CX, DI
	MOVQ DI, ret+40(FP)
	RET

cmp1:
	// In src's tail, compare 1 byte at a time.
	CMPQ DI, DX
	JAE  end
	MOVB (SI), AX
	MOVB (DI), BX
	CMPB AX, BX
	JNE  end
	ADDQ $1, SI
	ADDQ $1, DI
	JMP  cmp1

end:
	// Convert from &src[ret] to ret.
	SUBQ CX, DI
	MOVQ DI, ret+40(FP)
	RET
