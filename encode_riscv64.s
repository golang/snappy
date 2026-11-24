//go:build gc && !appengine && !noasm && riscv64
// +build gc,!appengine,!noasm,riscv64

#include "textflag.h"
#include "funcdata.h"
#include "go_asm.h"

// Persistent encodeBlock state. The private NOSPLIT leaf routines below use
// A0-A3 for arguments/results and T0-T4 as scratch, preserving these registers.
#define srcBase    S1
#define srcEnd     S2
#define searchEnd  S3
#define table      S4
#define hashShift  S5
#define multiplier S6
#define cursor     S7
#define nextEmit   S8
#define candidate  S9
#define output     A4

// Hash the low 32 bits and address the corresponding uint16 table entry.
#define HASH_SLOT(word, slot) \
	MULW multiplier, word, slot; \
	SRLW hashShift, slot, slot; \
	SLLI $1, slot; \
	ADD table, slot

#define PROBE_NEXT() \
	HASH_SLOT(A5, T1); \
	MOVHU (T1), candidate; \
	SUB srcBase, cursor, T2; \
	MOVH T2, (T1); \
	ADD srcBase, candidate; \
	MOVW (candidate), T2; \
	BEQ A5, T2, match; \
	ADD $1, cursor; \
	MOVW (cursor), A5

TEXT ·encodeBlock(SB), $32768-56
	NO_LOCAL_POINTERS
	MOV dst_base+0(FP), output
	MOV src_base+24(FP), srcBase
	MOV src_len+32(FP), T0
	ADD T0, srcBase, srcEnd
	SUB $const_inputMargin, srcEnd, searchEnd
	MOV $0x1e35a7bd, multiplier
	MOV $24, hashShift
	MOV $256, T1
	MOV $16384, T2
sizeTable:
	BGEU T1, T0, clearTable
	BEQ T1, T2, clearTable
	SLLI $1, T1
	SUB $1, hashShift
	JMP sizeTable

clearTable:
	MOV $hashTable-32768(SP), table
	SLLI $1, T1
	ADD table, T1
	MOV table, T0
clearWords:
	MOV ZERO, 0(T0)
	MOV ZERO, 8(T0)
	MOV ZERO, 16(T0)
	MOV ZERO, 24(T0)
	ADD $32, T0
	BLTU T0, T1, clearWords

	MOV srcBase, nextEmit
	ADD $1, srcBase, cursor
	MOVW (cursor), A5
startSearch:
	MOV $32, A6
	ADD $16, cursor, T0
	BGTU T0, searchEnd, probe
	MOV $4, A7
probeFour:
	PROBE_NEXT()
	PROBE_NEXT()
	PROBE_NEXT()
	PROBE_NEXT()
	SUB $1, A7
	BNEZ A7, probeFour
	ADD $16, A6
probe:
	SRLI $5, A6, T0
	ADD T0, cursor, A7
	BGTU A7, searchEnd, remainder
	ADD T0, A6
	HASH_SLOT(A5, T1)
	MOVHU (T1), candidate
	SUB srcBase, cursor, T2
	MOVH T2, (T1)
	ADD srcBase, candidate
	MOVW (candidate), T2
	BEQ A5, T2, match
	MOV A7, cursor
	MOVW (cursor), A5
	JMP probe

match:
	MOV output, A0
	MOV nextEmit, A1
	SUB nextEmit, cursor, A2
	CALL literal<>(SB)
	MOV A0, output
extend:
	ADD $4, cursor, A0
	ADD $4, candidate, A1
	MOV srcEnd, A2
	CALL matchEnd<>(SB)
	MOV A0, nextEmit
	SUB candidate, cursor, A1
	SUB cursor, nextEmit, A2
	MOV output, A0
	CALL copyTags<>(SB)
	MOV A0, output
	MOV nextEmit, cursor
	BGEU cursor, searchEnd, remainder

	// Insert cursor-1 before probing cursor, including when their hashes collide.
	MOV -1(cursor), T0
	HASH_SLOT(T0, T1)
	SUB srcBase, cursor, T2
	SUB $1, T2, T3
	MOVH T3, (T1)
	SRLI $8, T0
	HASH_SLOT(T0, T1)
	MOVHU (T1), candidate
	MOVH T2, (T1)
	ADD srcBase, candidate
	MOVW (candidate), T2
	MOVW T0, T3
	BEQ T2, T3, extend
	SRLI $8, T0
	MOVW T0, A5
	ADD $1, cursor
	JMP startSearch

remainder:
	BEQ nextEmit, srcEnd, encoded
	MOV output, A0
	MOV nextEmit, A1
	SUB nextEmit, srcEnd, A2
	CALL literal<>(SB)
	MOV A0, output
encoded:
	MOV dst_base+0(FP), T0
	SUB T0, output, T0
	MOV T0, d+48(FP)
	RET

TEXT ·extendMatch(SB), NOSPLIT, $0-48
	MOV src_base+0(FP), A3
	MOV i+24(FP), A1
	MOV j+32(FP), A0
	MOV src_len+8(FP), A2
	ADD A3, A0
	ADD A3, A1
	ADD A3, A2
	CALL matchEnd<>(SB)
	SUB A3, A0
	MOV A0, ret+40(FP)
	RET

// Advance A0 and the earlier pointer A1 over equal bytes, up to A2.
TEXT matchEnd<>(SB), NOSPLIT|NOFRAME, $0
	SUB $8, A2, T0
matchWords:
	BGTU A0, T0, matchBytes
	MOV (A0), T1
	MOV (A1), T2
	BNE T1, T2, differingWord
	ADD $8, A0
	ADD $8, A1
	JMP matchWords
differingWord:
	XOR T2, T1
	// (diff-1) & ^diff marks the bits below the first mismatch. Sum the
	// top bit of each byte to count complete matching bytes without Zbb.
	SUB $1, T1, T2
	XOR $-1, T1
	AND T2, T1
	SRLI $7, T1
	MOV $0x0101010101010101, T2
	AND T2, T1
	MUL T2, T1
	SRLI $56, T1
	ADD T1, A0
	RET
matchBytes:
	BEQ A0, A2, matched
	MOVBU (A0), T1
	MOVBU (A1), T2
	BNE T1, T2, matched
	ADD $1, A0
	ADD $1, A1
	JMP matchBytes
matched:
	RET

TEXT ·emitLiteral(SB), NOSPLIT, $0-56
	MOV dst_base+0(FP), A0
	MOV lit_base+24(FP), A1
	MOV lit_len+32(FP), A2
	CALL literal<>(SB)
	MOV dst_base+0(FP), T0
	SUB T0, A0
	MOV A0, ret+48(FP)
	RET

// Emit the length header and A2 bytes from A1. Return the new output in A0.
TEXT literal<>(SB), NOSPLIT|NOFRAME, $0
	SUB $1, A2, T0
	MOV $60, T1
	BGEU T0, T1, longLiteral
	SLLI $2, T0
	MOVB T0, (A0)
	ADD $1, A0
	JMP literalData
longLiteral:
	MOV $256, T1
	BGEU T0, T1, literal16
	MOV $240, T1
	MOVB T1, (A0)
	MOVB T0, 1(A0)
	ADD $2, A0
	JMP literalData
literal16:
	MOV $244, T1
	MOVB T1, (A0)
	MOVH T0, 1(A0)
	ADD $3, A0
literalData:
	MOV $8, T0
	BLTU A2, T0, literalBytes
literalWords:
	MOV (A1), T1
	MOV T1, (A0)
	ADD $8, A0
	ADD $8, A1
	SUB $8, A2
	BGEU A2, T0, literalWords
literalBytes:
	BEQZ A2, literalDone
	MOVBU (A1), T1
	MOVB T1, (A0)
	ADD $1, A0
	ADD $1, A1
	SUB $1, A2
	JMP literalBytes
literalDone:
	RET

TEXT ·emitCopy(SB), NOSPLIT, $0-48
	MOV dst_base+0(FP), A0
	MOV offset+24(FP), A1
	MOV length+32(FP), A2
	CALL copyTags<>(SB)
	MOV dst_base+0(FP), T0
	SUB T0, A0
	MOV A0, ret+40(FP)
	RET

// Encode offset A1, length A2. Leave at least four bytes for the final tag.
TEXT copyTags<>(SB), NOSPLIT|NOFRAME, $0
	MOV $68, T0
	MOV $254, T1
chunks64:
	BLTU A2, T0, lastChunk
	MOVB T1, (A0)
	MOVH A1, 1(A0)
	ADD $3, A0
	SUB $64, A2
	JMP chunks64
lastChunk:
	MOV $64, T0
	BLEU A2, T0, chooseTag
	MOV $238, T1
	MOVB T1, (A0)
	MOVH A1, 1(A0)
	ADD $3, A0
	SUB $60, A2
chooseTag:
	MOV $12, T0
	BGEU A2, T0, copy2
	SRLI $11, A1, T0
	BNEZ T0, copy2
	SRLI $8, A1, T0
	SLLI $5, T0
	SUB $4, A2, T1
	SLLI $2, T1
	OR T1, T0
	OR $const_tagCopy1, T0
	MOVB T0, (A0)
	MOVB A1, 1(A0)
	ADD $2, A0
	RET
copy2:
	SUB $1, A2, T0
	SLLI $2, T0
	OR $const_tagCopy2, T0
	MOVB T0, (A0)
	MOVH A1, 1(A0)
	ADD $3, A0
	RET
