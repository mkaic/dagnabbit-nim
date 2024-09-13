import std/bitops
import std/sequtils

type
  GateFunc* = enum
    gf_AND,
    gf_NAND,
    gf_OR,
    gf_NOR,
    gf_XOR,
    gf_XNOR,
    # gf_A,
    # gf_B,
    # gf_NOT_A,
    # gf_NOT_B
    # gf_NOT_A_AND_B,
    # gf_A_AND_NOT_B,
    # gf_NOT_A_OR_B,
    # gf_A_OR_NOT_B,
    # gf_ONE,
    # gf_ZERO

proc eval*(gf: GateFunc, inputs: seq[seq[int64]]): seq[int64] =
  # inputs is seq(2)[seq(num_batches)[int64]]
  var output: seq[int64]
  for (a, b) in zip(inputs[0], inputs[1]):
    case gf
    of gf_AND:
      output.add(bit_and(a, b))
    of gf_NAND:
      output.add(bit_not(bit_and(a, b)))
    of gf_OR:
      output.add(bit_or(a, b))
    of gf_NOR:
      output.add(bit_not(bit_or(a, b)))
    of gf_XOR:
      output.add(bit_xor(a, b))
    of gf_XNOR:
      output.add(bit_not(bit_xor(a, b)))
    # of gf_A:
    #   output.add(a)
    # of gf_B:
    #   output.add(b)
    # of gf_NOT_A:
    #   output.add(bit_not(a))
    # of gf_NOT_B:
    #   output.add(bit_not(b))
    # of gf_NOT_A_AND_B:
    #   output.add(bit_and(bit_not(a), b))
    # of gf_A_AND_NOT_B:
    #   output.add(bit_and(a, bit_not(b)))
    # of gf_NOT_A_OR_B:
    #   output.add(bit_or(bit_not(a), b))
    # of gf_A_OR_NOT_B:
    #   output.add(bit_or(a, bit_not(b)))
    # of gf_ONE:
    #   output.add(high(int64))
    # of gf_ZERO:
    #   output.add(low(int64))
  return output