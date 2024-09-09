# import std/sequtils
import std/sugar

# compile with `nim c -r --hints:off gate_dag.nim`
type
  Gate = ref object
    value: bool
    evaluated: bool
    inputs: array[2, Gate]
    outputs: seq[Gate]

  Graph = object
    inputs: seq[Gate]
    gates: seq[Gate]
    outputs: seq[Gate]

proc evaluate_gate(gate: Gate): bool =
  if not gate.evaluated:
    gate.value = not (gate.inputs[0].evaluate_gate() and gate.inputs[
        1].evaluate_gate())
    gate.evaluated = true

  return gate.value

proc evaluate_graph(self: var Graph): seq[bool] =
  return collect(newSeq):
    for o in self.outputs:
      o.evaluate_gate()

proc reset(graph: var Graph) =
  for g in graph.gates:
    g.evaluated = false
  for g in graph.outputs:
    g.evaluated = false

proc add_input(graph: var Graph, value: bool) =
  graph.inputs.add(Gate(value: value, evaluated: true))

proc add_gate(graph: var Graph, inputs: array[2, Gate],
    is_output: bool = false) =
  var g = Gate(inputs: inputs)
  for i in inputs:
    i.outputs.add(g)

  if is_output:
    graph.outputs.add(g)
  else:
    graph.gates.add(g)

proc get_descendants(gate: Gate, known: var seq[Gate]): seq[Gate] =
  for o in gate.outputs:
    if o notin known:
      known.add(o)
      discard get_descendants(o, known = known)
  return known

# This overloads the first get_descendants proc and tells it what to do if "known" isn't passed.
proc get_descendants(gate: Gate): seq[Gate] =
  var known = newSeq[Gate]()
  return get_descendants(gate, known = known)

var test_graph = Graph()

const input_values = [true, false, false, true, false, false, true, true]
for i in input_values:
  test_graph.add_input(i)

test_graph.add_gate(inputs = [test_graph.inputs[0], test_graph.inputs[1]])
test_graph.add_gate(inputs = [test_graph.inputs[1], test_graph.inputs[1]])

test_graph.add_gate(inputs = [test_graph.inputs[0], test_graph.gates[0]],
    is_output = true)

let outputs = test_graph.evaluate_graph()
echo outputs

let children = get_descendants(test_graph.inputs[0])
for c in children:
  echo c.value
