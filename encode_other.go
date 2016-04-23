// Copyright 2016 The Snappy-Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build !amd64 appengine !gc noasm

package snappy

// emitCopy writes a copy chunk and returns the number of bytes written.
//
// It assumes that:
//	dst is long enough to hold the encoded bytes
//	1 <= offset && offset <= 65535
//	4 <= length && length <= 65535
func emitCopy(dst []byte, offset, length int) int {
	i := 0
	// The maximum length for a single tagCopy1 or tagCopy2 op is 64 bytes. The
	// threshold for this loop is a little higher (at 68 = 64 + 4), and the
	// length emitted down below is is a little lower (at 60 = 64 - 4), because
	// it's shorter to encode a length 67 copy as a length 60 tagCopy2 followed
	// by a length 7 tagCopy1 (which encodes as 3+2 bytes) than to encode it as
	// a length 64 tagCopy2 followed by a length 3 tagCopy2 (which encodes as
	// 3+3 bytes). The magic 4 in the 64±4 is because the minimum length for a
	// tagCopy1 op is 4 bytes, which is why a length 3 copy has to be an
	// encodes-as-3-bytes tagCopy2 instead of an encodes-as-2-bytes tagCopy1.
	for length >= 68 {
		// Emit a length 64 copy, encoded as 3 bytes.
		dst[i+0] = 63<<2 | tagCopy2
		dst[i+1] = uint8(offset)
		dst[i+2] = uint8(offset >> 8)
		i += 3
		length -= 64
	}
	if length > 64 {
		// Emit a length 60 copy, encoded as 3 bytes.
		dst[i+0] = 59<<2 | tagCopy2
		dst[i+1] = uint8(offset)
		dst[i+2] = uint8(offset >> 8)
		i += 3
		length -= 60
	}
	if length >= 12 || offset >= 2048 {
		// Emit the remaining copy, encoded as 3 bytes.
		dst[i+0] = uint8(length-1)<<2 | tagCopy2
		dst[i+1] = uint8(offset)
		dst[i+2] = uint8(offset >> 8)
		return i + 3
	}
	// Emit the remaining copy, encoded as 2 bytes.
	dst[i+0] = uint8(offset>>8)<<5 | uint8(length-4)<<2 | tagCopy1
	dst[i+1] = uint8(offset)
	return i + 2
}

// extendMatch returns the largest k such that k <= len(src) and that
// src[i:i+k-j] and src[j:k] have the same contents.
//
// It assumes that:
//	0 <= i && i < j && j <= len(src)
func extendMatch(src []byte, i, j int) int {
	for ; j < len(src) && src[i] == src[j]; i, j = i+1, j+1 {
	}
	return j
}
