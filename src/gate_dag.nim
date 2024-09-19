# import std/sequtils
import ./gate_funcs
import ./bitty
import std/sugar
import std/random
import std/sequtils
import std/strformat
import std/tables
import std/hashes

randomize()

type
  GateRef* {.acyclic.} = ref object
    value*: BitArray
    evaluated*: bool

    inputs*: seq[GateRef]
    inputs_cache*: seq[GateRef]

    outputs*: seq[GateRef]

    function*: GateFunc = gf_NAND
    function_cache*: GateFunc

    id*: int

  Graph* = object
    inputs*: seq[GateRef]
    gates*: seq[GateRef]
    outputs*: seq[GateRef]
    id_autoincrement: int = 0

proc hash(gate: GateRef): Hash =
  return hash(gate.id)

proc eval(gate: GateRef) =
  if not gate.evaluated:
    assert gate.inputs[0].evaluated and gate.inputs[1].evaluated, "Inputs must be evaluated before gate"

    gate.value = gate.function.eval(
      gate.inputs[0].value,
      gate.inputs[1].value
    )
    gate.evaluated = true

proc eval*(graph: var Graph, bitpacked_inputs: seq[BitArray]): seq[BitArray] =

  for g in graph.gates:
    g.evaluated = false
  for o in graph.outputs:
    o.evaluated = false
  for i in graph.inputs:
    i.evaluated = true

  var output: seq[BitArray]

  for (i, v) in zip(graph.inputs, bitpacked_inputs):
    i.value = v

  for g in graph.gates:
    g.eval()

  for o in graph.outputs:
    o.eval()
    output.add(o.value)

  return output

proc kahn_topo_sort*(graph: var Graph) =
  var incoming_edges: Table[GateRef, int]
  var pending: seq[GateRef] = newSeq[GateRef]()
  var sorted: seq[GateRef] = newSeq[GateRef]()

  for g in (graph.outputs & graph.gates & graph.inputs):
    incoming_edges[g] = g.inputs.deduplicate().len
    if incoming_edges[g] == 0:
      pending.add(g)

  while pending.len > 0:

    let next_gate = pending[0]
    pending.del(0)
    sorted.add(next_gate)
    
    for o in next_gate.outputs.deduplicate():
      incoming_edges[o] -= 1
      if incoming_edges[o] == 0:
        pending.add(o)

  let cyclic = collect:
    for g in (graph.outputs & graph.gates & graph.inputs):
      if incoming_edges[g] != 0: &"{g.inputs.mapIt(it.id)} --> {g.id}"
  assert sorted.len == graph.outputs.len + graph.gates.len + graph.inputs.len, &"Graph is not connected, and only has len {sorted.len} instead of {graph.outputs.len + graph.gates.len + graph.inputs.len}. Unsorted gates: {cyclic}"
  assert all(sorted, proc (g: GateRef): bool = incoming_edges[g] == 0), &"Graph is not acyclic. Cyclic gates: {cyclic}"

  sorted = collect:
    for g in sorted:
      if g in graph.gates: g

  graph.gates = sorted


proc add_input*(graph: var Graph) =
  graph.inputs.add(GateRef(id: graph.id_autoincrement))
  graph.id_autoincrement += 1

proc connect*(new_input, gate: GateRef) =
  new_input.outputs.add(gate)
  gate.inputs.add(new_input)

proc disconnect*(old_input, gate: GateRef) =
  old_input.outputs.del(old_input.outputs.find(gate))
  gate.inputs.del(gate.inputs.find(old_input))

proc descendants_mapping*(gate: GateRef, graph: Graph): BitArray =

  var descendants = newBitArray(graph.id_autoincrement + 1)
  descendants.clear()

  # gate is counted as one of its own descendants
  # since connecting to itself would create a cycle
  descendants.unsafeSetTrue(gate.id)

  var pending = newSeq[GateRef]()
  pending.add(gate)

  while pending.len > 0:
    let next_gate = pending[0]
    
    for o in next_gate.outputs:
      if not descendants[o.id]:
        descendants.unsafeSetTrue(o.id)
        pending.add(o)

    pending.del(0)

  return descendants 
  # a mapping from every gate's ID in the graph to a bool for whether it's a descendant of the query gate.
  
proc add_random_gate*(graph: var Graph, output:bool = false) =

  assert graph.inputs.len > 0, "Graph must have inputs before adding gates"
  assert not (output and graph.gates.len == 0), "Graph must have gates before adding outputs"

  var new_gate= GateRef(id: graph.id_autoincrement)
  graph.id_autoincrement += 1

  for i in 0..1:
    let valid_inputs = (graph.inputs & graph.gates)
    connect(sample(valid_inputs), new_gate)

  if output:
    graph.outputs.add(new_gate)
  else:
    graph.gates.add(new_gate)

proc unpack_bitarrays_to_uint64*(packed: seq[BitArray]): seq[uint64] =
  # seq(8)[BitArray] --> seq(num_addresses)[uint64]
  var unpacked: seq[uint64] = newSeq[uint64](packed[0].len)
  for idx in 0 ..< packed[0].len:
    var as_uint64 = 0.uint64
    for bit_idx in 0 ..< packed.len:
      if packed[bit_idx].unsafeGet(idx):
        as_uint64 = as_uint64 or (1.uint64 shl bit_idx)
    unpacked[idx] = as_uint64

  return unpacked

proc stage_function_mutation*(gate: GateRef) =
  gate.function_cache = gate.function
  let available_functions = collect(newSeq):
    for f in GateFunc.low .. GateFunc.high:
      if f != gate.function: f
  gate.function = sample(available_functions)

proc undo_function_mutation*(gate: GateRef) =
  gate.function = gate.function_cache

proc stage_input_mutation*(gate: GateRef, graph: Graph) =
  gate.inputs_cache = gate.inputs
  let possible_inputs = (graph.inputs & graph.gates)
  
  for i in 0..1:
    let valid_inputs = collect:
      for g in possible_inputs:
        if not gate.descendants_mapping(graph)[g.id]: g

    var new_input_gate = sample(valid_inputs)

    disconnect(gate.inputs[i], gate)
    connect(new_input_gate, gate)

proc undo_input_mutation*(gate: GateRef) =
  for i in 0..1:
    disconnect(gate.inputs[i], gate)
    connect(gate.inputs_cache[i], gate)
