# import std/sequtils
# import std/sugar

# compile with `nim c -r --hints:off gate_dag.nim`
type
  Node = ref object
    id: int
    value: bool
    evaluated: bool
    inputs: seq[Node] = @[]

  Graph = object
    inputs: seq[Node]
    outputs: seq[Node]
    gates: seq[Node]

proc nand(self: Node) =
  assert self.kind == nkGate, "nand can only be called on Nodes"
  self.value = not (self.inputs[0].value and self.inputs[1].value)

proc add_gate(self: Graph) =
  let possible_inputs = self.inputs & self.gates
