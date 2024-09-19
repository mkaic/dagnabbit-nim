import bitty

type
  GateFunc* = enum
    gf_AND,
    gf_NAND,
    gf_OR,
    gf_NOR,
    gf_XOR,
    gf_XNOR,
    gf_A_AND_NOT_B,
    gf_A_OR_NOT_B,
    gf_NOT_A_AND_B,
    gf_NOT_A_OR_B,
    gf_A,
    gf_B,
    gf_NOT_A,
    gf_NOT_B,
    # gf_ZERO,
    # gf_ONE

proc eval*(gf: GateFunc, a, b: BitArray): BitArray =
  # inputs is seq(2)[seq(num_batches)[int64]]
  case gf
    of gf_AND:
      return a and b
    of gf_NAND:
      return not (a and b)
    of gf_OR:
      return a or b
    of gf_NOR:
      return not (a or b)
    of gf_XOR:
      return a xor b
    of gf_XNOR:
      return not (a xor b)
    of gf_A_AND_NOT_B:
      return a and not b
    of gf_A_OR_NOT_B:
      return a or not b
    of gf_NOT_A_AND_B:
      return not a and b
    of gf_NOT_A_OR_B:
      return not a or b
    of gf_A:
      return a
    of gf_B:
      return b
    of gf_NOT_A:
      return not a
    of gf_NOT_B:
      return not b
    # of gf_ZERO:
    #   return a xor a
    # of gf_ONE:
    #   return not a xor a
