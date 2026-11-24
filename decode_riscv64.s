//go:build gc && !appengine && !noasm && riscv64
// +build gc,!appengine,!noasm,riscv64

#include "textflag.h"
#include "go_asm.h"

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
	// For offset >= 8, each word is fully produced before it is read.
	BLTU offset, T1, bytes
	BLEU length, T1, shortCopy
	JMP words
shortCopy:
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
	BGTU length, T1, words
	BLTU T0, T1, bytes
	BLTU T2, T1, bytes
copyWord:
	// Both buffers have eight accessible bytes. Only length bytes are consumed.
	MOV (from), T2
	MOV T2, (output)
	ADD length, output
	JMP nextTag
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
