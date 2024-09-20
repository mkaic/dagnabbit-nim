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
    id*: int

    inputs*: seq[GateRef]
    inputs_cache*: seq[GateRef]

    function*: GateFunc = gf_NAND
    function_cache*: GateFunc

    # of length num_addresses
    value*: BitArray
    evaluated*: bool

    outputs*: seq[GateRef]

    # of length num_gates
    descendants*: BitArray

  Graph* = object
    inputs*: seq[GateRef]
    gates*: seq[GateRef]
    num_gates*: int
    outputs*: seq[GateRef]
    id_autoincrement*: int = 0

proc hash(gate: GateRef): Hash =
  return hash(gate.id)

proc all_nodes*(graph: Graph): seq[GateRef] =
  return graph.inputs & graph.gates & graph.outputs

proc connect*(new_input, gate: GateRef) =
  new_input.outputs.add(gate)
  gate.inputs.add(new_input)

proc disconnect*(old_input, gate: GateRef) =
  old_input.outputs.del(old_input.outputs.find(gate))
  gate.inputs.del(gate.inputs.find(old_input))

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

type SortMode* = enum sm_FORWARD, sm_BACKWARD
proc kahn_topo_sort*(nodes: seq[GateRef], mode: SortMode): seq[GateRef]=
  var incoming_edges: Table[int, int]
  var pending: seq[GateRef] = newSeq[GateRef]()
  var sorted: seq[GateRef] = newSeq[GateRef]()

  for g in nodes:
    case mode
      of sm_FORWARD:
        incoming_edges[g.id] = g.inputs.deduplicate().len
      of sm_BACKWARD:
        incoming_edges[g.id] = g.outputs.deduplicate().len

    if incoming_edges[g.id] == 0:
      pending.add(g)

  while pending.len > 0:

    let next_gate = pending[0]
    pending.del(0)
    sorted.add(next_gate)
    
    var outgoing_edges: seq[GateRef]
    case mode
      of sm_FORWARD:
        outgoing_edges = next_gate.outputs.deduplicate()
      of sm_BACKWARD:
        outgoing_edges = next_gate.inputs.deduplicate()

    for o in outgoing_edges:
      incoming_edges[o.id] -= 1
      if incoming_edges[o.id] == 0:
        pending.add(o)

  let cyclic = collect:
    for g in nodes:
      if incoming_edges[g.id] != 0: &"{g.inputs.mapIt(it.id)} --> {g.id}"

  assert sorted.len == nodes.len, 
    &"Graph is not connected, and only has len {sorted.len} instead of {nodes.len}. Unsorted gates: {cyclic}"
  assert all(sorted, proc (g: GateRef): bool = incoming_edges[g.id] == 0), 
    &"Graph is not acyclic. Cyclic gates: {cyclic}"

  return sorted

proc sort_gates*(graph: var Graph, mode: SortMode) =
  let sorted = kahn_topo_sort(graph.all_nodes(), mode)
  graph.gates = collect:
    for g in sorted:
      if g in graph.gates: g

proc add_input*(graph: var Graph) =
  graph.inputs.add(GateRef(id: graph.id_autoincrement))
  graph.id_autoincrement += 1

proc add_output*(graph: var Graph) =
  var output = GateRef(id: graph.id_autoincrement)
  graph.id_autoincrement += 1

  for i in 0..1:
    connect(sample(graph.inputs), output)

  graph.outputs.add(output)


proc update_descendants*(graph: var Graph) =

  let topo_sorted_backward = kahn_topo_sort(graph.all_nodes(), sm_BACKWARD)

  for g in topo_sorted_backward:
    var descendants = newBitArray(graph.inputs.len + graph.num_gates + graph.outputs.len)
    descendants.clear()

    # gate is counted as one of its own descendants
    # since connecting to itself would create a cycle
    descendants.unsafeSetTrue(g.id)

    for o in g.outputs:
      descendants = descendants or o.descendants

    # a mapping from every gate's ID in the graph to a bool for whether it's a descendant of the query gate.
    g.descendants = descendants
  
  
proc add_random_gate*(graph: var Graph, output:bool = false) =
  # non-wastefully adds gate by splitting an existing edge, ensuring that all gates "do something"

  assert graph.inputs.len > 0, "Graph must have inputs before adding gates"
  
  let split_output_gate_idx = rand(0 ..< graph.gates.len + graph.outputs.len)
  let is_graph_output = split_output_gate_idx >= graph.gates.len
  var split_output_gate: GateRef
  if is_graph_output:
    split_output_gate = graph.outputs[split_output_gate_idx - graph.gates.len]
  else:
    split_output_gate = graph.gates[split_output_gate_idx]

  var split_input_gate = sample(split_output_gate.inputs)

  var new_gate= GateRef(id: graph.id_autoincrement)
  graph.id_autoincrement += 1
  graph.gates.add(new_gate)

  disconnect(split_input_gate, split_output_gate)
  connect(split_input_gate, new_gate)
  connect(new_gate, split_output_gate)

  graph.update_descendants()

  let valid_gate_inputs = collect:
    for g in graph.gates:
      if (not new_gate.descendants[g.id]): g

  let all_valid_inputs = graph.inputs & valid_gate_inputs

  connect(sample(all_valid_inputs), new_gate)

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

proc stage_input_mutation*(gate: GateRef, graph: var Graph) =
  gate.inputs_cache = gate.inputs

  for i in 0..1:
    let valid_inputs = collect:
      for g in graph.gates:
        if not gate.descendants[g.id]: g

    let all_valid_inputs = graph.inputs & valid_inputs
    var new_input_gate = sample(all_valid_inputs)

    disconnect(gate.inputs[i], gate)
    connect(new_input_gate, gate)

    graph.sort_gates(sm_FORWARD)

proc undo_input_mutation*(gate: GateRef, graph: var Graph) =
  for i in 0..1:
    disconnect(gate.inputs[i], gate)
    connect(gate.inputs_cache[i], gate)

  graph.sort_gates(sm_FORWARD)
