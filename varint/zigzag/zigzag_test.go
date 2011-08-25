// Copyright 2011 The Snappy-Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package zigzag

import (
	"testing"
)

var testCases = []struct {
	u uint64
	i int64
}{
	{0, +0},
	{1, -1},
	{2, +1},
	{3, -2},
	{4, +2},
	{5, -3},
	{6, +3},
	{199, -100},
	{200, +100},
	{1<<32 - 2, +1<<31 - 1},
	{1<<32 - 1, -1<<31 - 0},
	{1<<32 + 0, +1<<31 + 0},
	{1<<32 + 1, -1<<31 - 1},
	{1<<32 + 2, +1<<31 + 1},
	{1<<64 - 2, +1<<63 - 1},
	{1<<64 - 1, -1<<63 + 0},
}

func TestZigzag(t *testing.T) {
	for _, tc := range testCases {
		if i := Utoi64(tc.u); i != tc.i {
			t.Errorf("uint64 %d to int64: want %d got %d", tc.u, tc.i, i)
		}
		if u := Itou64(tc.i); u != tc.u {
			t.Errorf("int64 %d to uint64: want %d got %d", tc.i, tc.u, u)
		}
	}
}
