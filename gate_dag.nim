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

  Graph* = object
    inputs: seq[Gate]
    gates: seq[Gate]
    outputs: seq[Gate]

proc evaluate_gate*(gate: Gate): bool =
  if not gate.evaluated:
    gate.value = not (gate.inputs[0].evaluate_gate() and gate.inputs[
        1].evaluate_gate())
    gate.evaluated = true

  return gate.value

proc evaluate_graph*(self: var Graph): seq[bool] =
  return collect(newSeq):
    for o in self.outputs:
      o.evaluate_gate()

proc reset*(graph: var Graph) =
  for g in graph.gates:
    g.evaluated = false
  for g in graph.outputs:
    g.evaluated = false

proc add_input*(graph: var Graph) =
  graph.inputs.add(Gate(value: true, evaluated: true))


# proc get_ancestors(gate: Gate, known: var seq[Gate]): seq[Gate] =
#   for o in gate.inputs:
#     if o notin known:
#       known.add(o)
#       discard get_ancestors(o, known = known)
#   return known

# # This overloads the first get_ancestors proc and tells it what to do if "known" isn't passed.
# proc get_ancestors(gate: Gate): seq[Gate] =
#   var known = newSeq[Gate]()
#   return get_ancestors(gate, known = known)

proc init_gate*(graph: var Graph, output: bool = false) =

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

proc set_inputs*(graph: var Graph, input_values: seq[bool]) =
  for i, v in input_values:
    graph.inputs[i].value = v

proc int_to_bool_seq*(i: int, bits: int): seq[bool] =
  return collect(newSeq):
    for b in 0 ..< bits: (i and (1 shl b)) > 0

proc bool_seq_to_int*(seq: seq[bool]): int =
  var output = 0
  for i, v in seq:
    if v:
      output = output or (1 shl i)
  return output
