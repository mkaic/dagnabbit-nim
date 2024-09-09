# import std/sequtils
# import std/sugar
import std/tables
import std/strformat

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
    global_counter: int = 0
    inputs: Table[string, Input] = initTable[string, Input]()
    outputs: Table[string, Gate] = initTable[string, Gate]()
    gates: Table[string, Gate] = initTable[string, Gate]()

proc add_input(self: var Graph) =
  var node_id = &"i{self.global_counter}"
  self.inputs[node_id] = Input(id: node_id, value: false)
  self.global_counter += 1

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
