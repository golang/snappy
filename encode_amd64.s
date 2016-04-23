// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build !appengine
// +build gc
// +build !noasm

#include "textflag.h"

// The asm code generally follows the pure Go code in encode_other.go, except
// where marked with a "!!!".

// ----------------------------------------------------------------------------

// func emitLiteral(dst, lit []byte) int
//
// All local variables fit into registers. The register allocation:
//	- AX	return value
//	- BX	n
//	- CX	len(lit)
//	- SI	&lit[0]
//	- DI	&dst[i]
//
// The 24 bytes of stack space is to call runtime·memmove.
TEXT ·emitLiteral(SB), NOSPLIT, $24-56
	MOVQ dst_base+0(FP), DI
	MOVQ lit_base+24(FP), SI
	MOVQ lit_len+32(FP), CX
	MOVQ CX, AX
	MOVL CX, BX
	SUBL $1, BX

	CMPL BX, $60
	JLT  oneByte
	CMPL BX, $256
	JLT  twoBytes

threeBytes:
	MOVB $0xf4, 0(DI)
	MOVW BX, 1(DI)
	ADDQ $3, DI
	ADDQ $3, AX
	JMP  end

twoBytes:
	MOVB $0xf0, 0(DI)
	MOVB BX, 1(DI)
	ADDQ $2, DI
	ADDQ $2, AX
	JMP  end

oneByte:
	SHLB $2, BX
	MOVB BX, 0(DI)
	ADDQ $1, DI
	ADDQ $1, AX

end:
	MOVQ AX, ret+48(FP)

	// copy(dst[i:], lit)
	//
	// This means calling runtime·memmove(&dst[i], &lit[0], len(lit)), so we push
	// DI, SI and CX as arguments.
	MOVQ DI, 0(SP)
	MOVQ SI, 8(SP)
	MOVQ CX, 16(SP)
	CALL runtime·memmove(SB)
	RET

// ----------------------------------------------------------------------------

// func emitCopy(dst []byte, offset, length int) int
//
// All local variables fit into registers. The register allocation:
//	- BX	offset
//	- CX	length
//	- SI	&dst[0]
//	- DI	&dst[i]
TEXT ·emitCopy(SB), NOSPLIT, $0-48
	MOVQ dst_base+0(FP), DI
	MOVQ DI, SI
	MOVQ offset+24(FP), BX
	MOVQ length+32(FP), CX

loop0:
	// for length >= 68 { etc }
	CMPL CX, $68
	JLT  step1

	// Emit a length 64 copy, encoded as 3 bytes.
	MOVB $0xfe, 0(DI)
	MOVW BX, 1(DI)
	ADDQ $3, DI
	SUBL $64, CX
	JMP  loop0

step1:
	// if length > 64 { etc }
	CMPL CX, $64
	JLE  step2

	// Emit a length 60 copy, encoded as 3 bytes.
	MOVB $0xee, 0(DI)
	MOVW BX, 1(DI)
	ADDQ $3, DI
	SUBL $60, CX

step2:
	// if length >= 12 || offset >= 2048 { goto step3 }
	CMPL CX, $12
	JGE  step3
	CMPL BX, $2048
	JGE  step3

	// Emit the remaining copy, encoded as 2 bytes.
	MOVB BX, 1(DI)
	SHRL $8, BX
	SHLB $5, BX
	SUBB $4, CX
	SHLB $2, CX
	ORB  CX, BX
	ORB  $1, BX
	MOVB BX, 0(DI)
	ADDQ $2, DI

	// Return the number of bytes written.
	SUBQ SI, DI
	MOVQ DI, ret+40(FP)
	RET

step3:
	// Emit the remaining copy, encoded as 3 bytes.
	SUBL $1, CX
	SHLB $2, CX
	ORB  $2, CX
	MOVB CX, 0(DI)
	MOVW BX, 1(DI)
	ADDQ $3, DI

	// Return the number of bytes written.
	SUBQ SI, DI
	MOVQ DI, ret+40(FP)
	RET

// ----------------------------------------------------------------------------

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
