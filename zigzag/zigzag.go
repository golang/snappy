// Copyright 2011 The Snappy-Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package zigzag implements the zigzag mapping between signed and unsigned
// integers:
//	+0 <--> 0
//	-1 <--> 1
//	+1 <--> 2
//	-2 <--> 3
//	+2 <--> 4
//
// It is the same format used by protocol buffers. The format is described at
// http://code.google.com/apis/protocolbuffers/docs/encoding.html
package zigzag

func Itou64(i int64) uint64 {
	return uint64(i<<1 ^ i>>63)
}

func Utoi64(u uint64) int64 {
	return int64(u>>1) ^ -int64(u&1)
}
