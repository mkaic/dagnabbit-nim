import std/bitops

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
  # of gf_A:
  #   return inputs[0]
  # of gf_B:
  #   return inputs[1]
  # of gf_NOT_A:
  #   return bit_not(inputs[0])
  # of gf_NOT_B:
  #   return bit_not(inputs[1])
  # of gf_NOT_A_AND_B:
  #   return bit_and(bit_not(inputs[0]), inputs[1])
  # of gf_A_AND_NOT_B:
  #   return bit_and(inputs[0], bit_not(inputs[1]))
  # of gf_NOT_A_OR_B:
  #   return bit_or(bit_not(inputs[0]), inputs[1])
  # of gf_A_OR_NOT_B:
  #   return bit_or(inputs[0], bit_not(inputs[1]))
  # of gf_ONE:
  #   return high(int64)
  # of gf_ZERO:
  #   return low(int64)