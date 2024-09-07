type Gate = ref object
  id: int
  inputs: array[2, Gate]
  outputs: seq[Gate]
  value: bool

proc nand(g: Gate): bool =
  g.value = not (g.inputs[0].value and g.inputs[1].value)

# compile with `nim c -r --hints:off gate_dag.nim`