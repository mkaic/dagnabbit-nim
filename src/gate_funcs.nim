import bitty

type
  GateFunc* = enum
    gf_AND,
    gf_NAND,
    # gf_OR,
    # gf_NOR,
    # gf_XOR,
    # gf_XNOR,
    # gf_ONE,
    # gf_ZERO

proc eval*(gf: GateFunc, a, b: BitArray): BitArray =
  # inputs is seq(2)[seq(num_batches)[int64]]
  case gf
    of gf_AND:
      return a and b
    of gf_NAND:
      return not (a and b)
    # of gf_OR:
    #   return a or b
    # of gf_NOR:
    #   return not (a or b)
    # of gf_XOR:
    #   return a xor b
    # of gf_XNOR:
    #   return not (a xor b)
    # of gf_ONE:
    #   return not (a xor a)
    # of gf_ZERO:
    #   return a xor a
