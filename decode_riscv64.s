//go:build gc && !appengine && !noasm && riscv64
// +build gc,!appengine,!noasm,riscv64

#include "textflag.h"
#include "go_asm.h"

#ifdef GORISCV64_rva23u64
#include "asm_riscv64.h"
#define SNAPPY_RVV
#else
#ifdef const_offsetRISCV64HasV
#define SNAPPY_RVV
#endif
#endif

#define input    A0
#define inputEnd A1
#define output   A2
#define outEnd   A3
#define outBase  A4
#define length   A5
#define offset   A6
#define from     A7

TEXT ·decode(SB), NOSPLIT, $0-56
	MOV src_base+24(FP), input
	MOV src_len+32(FP), inputEnd
	ADD input, inputEnd
	MOV dst_base+0(FP), outBase
	MOV outBase, output
	MOV dst_len+8(FP), outEnd
	ADD output, outEnd
nextTag:
	BEQ input, inputEnd, end
	MOVBU (input), T0
	ADD $1, input
	AND $3, T0, T1
	SRLI $2, T0, length
	BEQZ T1, literal
	MOV $const_tagCopy1, T2
	BEQ T1, T2, copy1
	SUB input, inputEnd, T2
	MOV $const_tagCopy2, T3
	BNE T1, T3, copy4
copy2:
	MOV $2, T3
	BLTU T2, T3, corrupt
	MOVHU (input), offset
	ADD $2, input
	ADD $1, length
	JMP checkCopy
copy4:
	MOV $4, T3
	BLTU T2, T3, corrupt
	MOVWU (input), offset
	ADD $4, input
	ADD $1, length
	JMP checkCopy
copy1:
	BEQ input, inputEnd, corrupt
	AND $0xe0, T0, offset
	SLLI $3, offset
	MOVBU (input), T2
	OR T2, offset
	ADD $1, input
	AND $7, length
	ADD $4, length
checkCopy:
	BEQZ offset, corrupt
	SUB outBase, output, T0
	BGTU offset, T0, corrupt
	SUB output, outEnd, T0
	BGTU length, T0, corrupt
	SUB offset, output, from
	MOV $8, T1
#ifdef SNAPPY_RVV
	BGTU length, T1, wideBackref
	BLTU offset, T1, bytes
#else
	BLTU offset, T1, bytes
	BGTU length, T1, words
#endif
	BLTU T0, T1, bytes
	JMP copyWord

literal:
	MOV $60, T1
	BLTU length, T1, literalLength
	// The next one to four bytes encode length-1 in little-endian order.
	SUB $59, length, T1
	SUB input, inputEnd, T2
	BGTU T1, T2, corrupt
	MOV ZERO, length
	MOV ZERO, T2
lengthByte:
	MOVBU (input), T3
	SLL T2, T3, T3
	OR T3, length
	ADD $8, T2
	ADD $1, input
	SUB $1, T1
	BNEZ T1, lengthByte
literalLength:
	ADD $1, length
	SUB input, inputEnd, T0
	BGTU length, T0, corrupt
	SUB output, outEnd, T2
	BGTU length, T2, corrupt
	MOV input, from
	ADD length, input
	MOV $8, T1
	BGTU length, T1, readyCopy
	BLTU T0, T1, bytes
	BLTU T2, T1, bytes
copyWord:
	// Both buffers have eight accessible bytes. Only length bytes are consumed.
	MOV (from), T2
	MOV T2, (output)
	ADD length, output
	JMP nextTag
readyCopy:
#ifdef SNAPPY_RVV
#ifndef hasV
	MOVB internal∕cpu·RISCV64+const_offsetRISCV64HasV(SB), X5
	BEQZ X5, words
#endif
	MOV $64, T0
	BLEU length, T0, shortVector
	VSETVLI length, E8, M8, TA, MA, T2
literalChunks:
	VLE8V (from), V8
	VSE8V V8, (output)
	ADD T2, from
	ADD T2, output
	SUB T2, length
	BGEU length, T2, literalChunks
	BEQZ length, nextTag
	VSETVLI length, E8, M8, TA, MA, ZERO
	JMP loadVector

wideBackref:
#ifndef hasV
	MOVB internal∕cpu·RISCV64+const_offsetRISCV64HasV(SB), X5
	BEQZ X5, scalarWideBackref
#endif
	BGEU offset, length, shortVector
	MOV $1, T0
	BEQ offset, T0, repeatByte
expandPattern:
	VSETVLI offset, E8, M4, TA, MA, ZERO
	VLE8V (from), V8
	VSE8V V8, (output)
	ADD offset, output
	SUB offset, length
	SLLI $1, offset
	BLTU offset, length, expandPattern
shortVector:
	VSETVLI length, E8, M4, TA, MA, ZERO
loadVector:
	VLE8V (from), V8
storeVector:
	VSE8V V8, (output)
	ADD length, output
	JMP nextTag
repeatByte:
	MOVBU (from), T0
	VSETVLI length, E8, M4, TA, MA, ZERO
	VMVVX T0, V8
	JMP storeVector
#ifndef hasV
scalarWideBackref:
	BLTU offset, T1, bytes
#endif
#endif
words:
	BLTU length, T1, bytes
	MOV (from), T2
	MOV T2, (output)
	ADD $8, from
	ADD $8, output
	SUB $8, length
	JMP words
bytes:
	BEQZ length, nextTag
	MOVBU (from), T2
	MOVB T2, (output)
	ADD $1, from
	ADD $1, output
	SUB $1, length
	JMP bytes
end:
	BNE output, outEnd, corrupt
	MOV ZERO, ret+48(FP)
	RET
corrupt:
	MOV $const_decodeErrCodeCorrupt, T0
	MOV T0, ret+48(FP)
	RET
