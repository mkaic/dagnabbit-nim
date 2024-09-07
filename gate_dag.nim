type Gate = ref object
  id: int
  input_a: Gate
  input_b: Gate
  outputs: seq[Gate]
  value: int

proc nand(g: Gate): bool =
  g.value = not (g.input_a.value and g.input_b.value)

# compile with `nim c -r --hints:off gate_dag.nim`