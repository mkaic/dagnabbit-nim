import std/bitops

type
  GateFunc* = enum
    gf_AND,
    gf_NAND,
    gf_OR,
    gf_NOR,
    gf_XOR,
    gf_XNOR,
    # gf_ONE,
    # gf_ZERO

proc eval*(gf: GateFunc, inputs: array[2, int64]): int64 =
  case gf
  of gf_AND:
    return bit_and(inputs[0], inputs[1])
  of gf_NAND:
    return bit_not(bit_and(inputs[0], inputs[1]))
  of gf_OR:
    return bit_or(inputs[0], inputs[1])
  of gf_NOR:
    return bit_not(bit_or(inputs[0], inputs[1]))
  of gf_XOR:
    return bit_xor(inputs[0], inputs[1])
  of gf_XNOR:
    return bit_not(bit_xor(inputs[0], inputs[1]))
  # of gf_ONE:
  #   return bit_not(0'i64)
  # of gf_ZERO:
  #   return 0'i64