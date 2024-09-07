type Gate = ref object
  id: int
  inputs: seq[Gate]
  outputs: seq[Gate]
  value: int

proc nand(g: Gate): bool =
  g.value = not (g.inputs[0].value and g.inputs[1].value)

# compile with `nim c -r gate_dag.nim`