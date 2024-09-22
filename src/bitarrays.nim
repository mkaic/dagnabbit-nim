# Vendored in from https://github.com/treeform/bitty/blob/master/src/bitty.nim
# Thanks treeform! I (mkaic) have pasted your license below :)

# The MIT License (MIT)

# Copyright (c) 2020 Andre von Houck

# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import hashes, bitops

func divUp(a, b: int): int =
  ## Like div, but rounds up instead of down.
  let extra = if a mod b > 0: 1 else: 0
  return a div b + extra

type BitArray*[L: static int] = ref object
  ## Creates an array of bits all packed in together.
  bits: array[L.divUp(64), uint64]
  len: int
  
func newBitArray*(len: static int): BitArray[len] =
  ## Create a new bit array.
  return BitArray[len](len: len)

func setLen*(b: BitArray, len: int) =
  ## Sets the length.
  b.len = len
  b.bits.setLen(len.divUp(64))

when defined(release):
  {.push checks: off.}

func firstFalse*(b: BitArray): (bool, int) =
  for i, bits in b.bits:
    if bits == 0:
      return (true, i * 64)
    if bits != uint64.high:
      let matchingBits = firstSetBit(not bits)
      return (true, i * 64 + matchingBits - 1)
  (false, 0)

func unsafeGet*(b: BitArray, i: int): bool =
  ## Access a single bit (unchecked).
  let
    bigAt = i div 64
    littleAt = i mod 64
    mask = 1.uint64 shl littleAt
  return (b.bits[bigAt] and mask) != 0

func unsafeSetFalse*(b: BitArray, i: int) =
  ## Set a single bit to false (unchecked).
  let
    bigAt = i div 64
    littleAt = i mod 64
    mask = 1.uint64 shl littleAt
  b.bits[bigAt] = b.bits[bigAt] and (not mask)

func unsafeSetTrue*(b: BitArray, i: int) =
  ## Set a single bit to true (unchecked).
  let
    bigAt = i div 64
    littleAt = i mod 64
    mask = 1.uint64 shl littleAt
  b.bits[bigAt] = b.bits[bigAt] or mask

iterator trueIndexes*(b: BitArray): int =
  var j: int
  for i, bits in b.bits:
    if bits == 0:
      continue
    j = 0
    while j < 64:
      let v = bits and (uint64.high shl j)
      if v == 0:
        break
      j = firstSetBit(v)
      yield i * 64 + j - 1

when defined(release):
  {.pop.}

func `[]`*(b: BitArray, i: int): bool =
  ## Access a single bit.
  if i < 0 or i >= b.len:
    raise newException(IndexDefect, "Index out of bounds")
  b.unsafeGet(i)

func `[]=`*(b: BitArray, i: int, v: bool) =
  # Set a single bit.
  if i < 0 or i >= b.len:
    raise newException(IndexDefect, "Index out of bounds")
  if v:
    b.unsafeSetTrue(i)
  else:
    b.unsafeSetFalse(i)

func `==`*(a, b: BitArray): bool =
  ## Are two bit arrays the same.
  if b.isNil or a.len != b.len:
    return false
  for i in 0 ..< a.bits.len:
    if a.bits[i] != b.bits[i]:
      return false
  return true

func `and`*(a, b: BitArray): BitArray =
  ## And(s) two bit arrays returning a new bit array.
  if a.len != b.len:
    raise newException(ValueError, "Bit arrays are not same length")
  result = newBitArray(a.len)
  for i in 0 ..< a.bits.len:
    result.bits[i] = a.bits[i] and b.bits[i]

func `or`*(a, b: BitArray): BitArray =
  ## Or(s) two bit arrays returning a new bit array.
  if a.len != b.len:
    raise newException(ValueError, "Bit arrays are not same length")
  result = newBitArray(a.len)
  for i in 0 ..< a.bits.len:
    result.bits[i] = a.bits[i] or b.bits[i]

# This function was not included in the original source. I (mkaic) added it myself.
func `xor`*(a, b: BitArray): BitArray =
  ## Xor(s) two bit arrays returning a new bit array.
  if a.len != b.len:
    raise newException(ValueError, "Bit arrays are not same length")
  result = newBitArray(a.len)
  for i in 0 ..< a.bits.len:
    result.bits[i] = a.bits[i] xor b.bits[i]

func `not`*(a: BitArray): BitArray =
  ## Not(s) or inverts a and returns a new bit array.
  result = newBitArray(a.len)
  for i in 0 ..< a.bits.len:
    result.bits[i] = not a.bits[i]

func `$`*(b: BitArray): string =
  ## Turns the bit array into a string.
  result = newStringOfCap(b.len)
  for i in 0 ..< b.len:
    if b.unsafeGet(i):
      result.add "1"
    else:
      result.add "0"

func add*(b: BitArray, v: bool) =
  ## Add a bit to the end of the array.
  let
    i = b.len
  b.len += 1
  if b.len.divUp(64) > b.bits.len:
    b.bits.add(0)
  if v:
    let
      bigAt = i div 64
      littleAt = i mod 64
      mask = 1.uint64 shl littleAt
    b.bits[bigAt] = b.bits[bigAt] or mask

func count*(b: BitArray): int =
  ## Returns the number of bits set.
  for i in 0 ..< b.bits.len:
    result += countSetBits(b.bits[i])

func clear*(b: BitArray) =
  ## Unsets all of the bits.
  for i in 0 ..< b.bits.len:
    b.bits[i] = 0

func hash*(b: BitArray): Hash =
  ## Computes a Hash for the bit array.
  hash((b.bits, b.len))

iterator items*(b: BitArray): bool =
  for i in 0 ..< b.len:
    yield b.unsafeGet(i)

iterator pairs*(b: BitArray): (int, bool) =
  for i in 0 ..< b.len:
    yield (i, b.unsafeGet(i))

proc unpack_bitarrays_to_uint64*(packed: seq[BitArray]): seq[uint64] =
  # seq(8)[BitArray] --> seq(num_addresses)[uint64]
  var unpacked: seq[uint64] = newSeq[uint64](packed[0].len)
  for idx in 0 ..< packed[0].len:
    var as_uint64 = 0.uint64
    for bit_idx in 0 ..< packed.len:
      if packed[bit_idx].unsafeGet(idx):
        as_uint64 = as_uint64 or (1.uint64 shl bit_idx)
    unpacked[idx] = as_uint64

  return unpacked
