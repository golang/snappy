// Copyright 2011 The Snappy-Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package varint

import (
	"testing"
)

var testCases = []struct {
	valid bool
	s     string
	v     uint64
}{
	// Valid encodings.
	{true, "\x00", 0},
	{true, "\x01", 1},
	{true, "\x7f", 127},
	{true, "\x80\x01", 128},
	{true, "\xff\x02", 383},
	{true, "\x9e\xa7\x05", 86942}, // 86942 = 0x1e + 0x27<<7 + 0x05<<14
	{true, "\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01", 0xffffffffffffffff},
	{
		true,
		"\x8a\x89\x88\x87\x86\x85\x84\x83\x82\x01",
		10 + 9<<7 + 8<<14 + 7<<21 + 6<<28 + 5<<35 + 4<<42 + 3<<49 + 2<<56 + 1<<63,
	},
	// Invalid encodings.
	{false, "", 0},
	{false, "\x80", 0},
	{false, "\xff", 0},
	{false, "\x9e\xa7", 0},
}

func TestDecode(t *testing.T) {
	for _, tc := range testCases {
		v, n := Decode([]byte(tc.s))
		if v != tc.v {
			t.Errorf("decode %q: want value %d got %d", tc.s, tc.v, v)
			continue
		}
		m := 0
		if tc.valid {
			m = len(tc.s)
		}
		if n != m {
			t.Errorf("decode %q: want length %d got %d", tc.s, m, n)
			continue
		}
	}
}

func TestEncode(t *testing.T) {
	for _, tc := range testCases {
		if !tc.valid {
			continue
		}
		var b [MaxLen]byte
		n := Encode(b[:], tc.v)
		if s := string(b[:n]); s != tc.s {
			t.Errorf("encode %d: want bytes %q got %q", tc.v, tc.s, s)
			continue
		}
		if n != Len(tc.v) {
			t.Errorf("encode %d: Encode length %d != Len length %d", tc.v, n, Len(tc.v))
			continue
		}
	}
}
