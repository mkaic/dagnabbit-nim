# import std/sequtils
import std/sugar
import std/tables
import std/strformat

# compile with `nim c -r --hints:off gate_dag.nim`
type
  Input = ref object
    id: int
    value: bool

  Gate = ref object
    id: int
    value: bool
    evaluated: bool
    inputs: array[2, string]
    outputs: seq[string]

  Graph = object
    global_counter: int = 0
    inputs: seq[Input]
    outputs: seq[Gate]
    gates: seq[Gate]

proc evaluate_gate(graph: Graph, gate: Gate): bool =
  if not gate.evaluated:
    gate.value


proc add_input(self: var Graph) =
  var node_id = &"i{self.global_counter}"
  self.inputs.add(Input(id: node_id, value: false))
  self.global_counter += 1

proc add_gate(self: var Graph) =
  var node_id = &"g{self.global_counter}"
  self.gates.add(
    Gate(
      id: node_id,
      value: false,
      evaluated: false,
      inputs: ["", ""],
      outputs: @[],
    )
  )
  self.global_counter += 1

proc add_output(self: var Graph) =
  var node_id = &"o{self.global_counter}"
  self.outputs.add(
    Gate(
      id: node_id,
      value: false,
      evaluated: false,
      inputs: ["", ""],
      outputs: @[],
    )
  )
  self.global_counter += 1

proc evaluate(self: var Graph): seq[bool] =
  for o in self.outputs.values():
    o.evaluate_gate()

  return collect(newSeq):
    for o in self.outputs.values(): o.value

var test_graph = Graph()

test_graph.add_input()
test_graph.add_input()

test_graph.gates["g0"] = Gate(
  id: "g0",
  value: false,
  evaluated: false,
  inputs: ["i0", "i1"],
  outputs: @["o0"],
  )

test_graph.outputs["o0"] = Gate(
  id: "o0",
  value: false,
  evaluated: false,
  inputs: ["g0", "g0"],
  outputs: @[],
  )
