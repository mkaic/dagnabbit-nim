# import std/sequtils
# import std/sugar
from std/tables import TableRef

# compile with `nim c -r --hints:off gate_dag.nim`
type

  Input = ref object
    id: string
    value: bool

  Gate = ref object
    id: string
    value: bool
    evaluated: bool
    inputs: array[2, string]
    outputs: seq[string]

  Graph = object
    inputs: TableRef[string, Input]
    outputs: TableRef[string, Gate]
    gates: TableRef[string, Gate]

var test_graph: Graph = Graph()

test_graph.inputs["i0"] = Input(id: "i0", value: true)
test_graph.inputs["i1"] = Input(id: "i1", value: true)

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
