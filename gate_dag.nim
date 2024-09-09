# import std/sequtils
import std/sugar
import std/random

randomize()

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

proc init_gate(graph: var Graph, output: bool = false) = 
  
  let available_graph_inputs = graph.inputs & graph.gates
  var gate_inputs: array[2, Gate]
  for i in 0..1:
    gate_inputs[i] = available_graph_inputs[rand(available_graph_inputs.len - 1)]

  var g = Gate(inputs: gate_inputs)

  for i in gate_inputs:
    i.outputs.add(g)

  if output:
    graph.outputs.add(g)
  else:
    graph.gates.add(g)


var test_graph = Graph()

const input_values = [true, false, false, true, false, false, true, true]
for i in input_values:
  test_graph.add_input(i)

for i in 1..20:
  test_graph.init_gate()

for i in 1..3:
  test_graph.init_gate(output = true)

let outputs = test_graph.evaluate_graph()
echo outputs
