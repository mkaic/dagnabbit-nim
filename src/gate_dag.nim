# import std/sequtils
import ./config 
import ./gate_funcs
import ./bitarrays

import std/sugar
import std/random
import std/sequtils
import std/strformat
import std/tables
import std/hashes
import std/algorithm

randomize()

type
  NodeID = distinct int
  Node = object
    id: NodeID
    inputs: array[2, NodeID]

    function: GateFunc = gf_NAND

    # of length num_addresses
    value: BitArray
    evaluated: bool

    # of length num_gates
    descendants: BitArray

  Graph = object
    inputs: array[address_bitcount, NodeID]
    outputs: array[output_bitcount, NodeID]

    nodes: array[num_gates, Node]
    evaluated: BitArray

    execution_order: array[num_gates, NodeID]

    id_autoincrement: int = 0

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

proc kahn_topo_sort*(nodes: seq[GateRef]): seq[GateRef]=
  var incoming_edges: Table[int, int]
  var pending: seq[GateRef] = newSeq[GateRef]()
  var sorted: seq[GateRef] = newSeq[GateRef]()

  for g in nodes:
    incoming_edges[g.id] = g.inputs.deduplicate().len

    if incoming_edges[g.id] == 0:
      pending.add(g)

  while pending.len > 0:

    let next_gate = pending[0]
    pending.del(0)
    sorted.add(next_gate)

    for o in next_gate.outputs.deduplicate():
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

proc refresh_descendants(gate: GateRef) =
  var descendants = newBitArray(gate.descendants.len)
  descendants.clear()
  descendants.unsafeSetTrue(gate.id)

  for o in gate.outputs:
    descendants = descendants or o.descendants

  # a mapping from every gate's ID in the graph to a bool for whether it's a descendant of the query gate.
  gate.descendants = descendants

proc refresh_descendants_until(graph: var Graph, gate: GateRef) =
  let sorted = kahn_topo_sort(graph.all_nodes()).reversed()
  for g in sorted:
    g.refresh_descendants()
    if g == gate: break

proc sort_gates*(graph: var Graph) =
  let sorted = kahn_topo_sort(graph.all_nodes())
  graph.gates = collect:
    for g in sorted:
      if g in graph.gates: g

proc create_node*(graph: var Graph): GateRef =
  var node = GateRef(id: graph.id_autoincrement, descendants: newBitArray(graph.total_nodes))
  graph.id_autoincrement += 1
  return node

proc add_input*(graph: var Graph) =
  var input = graph.create_node()
  graph.inputs.add(input)

proc add_output*(graph: var Graph) =
  var output = graph.create_node()

  for i in 0..1:
    connect(sample(graph.inputs), output)

  graph.outputs.add(output)  
  
proc add_random_gate*(graph: var Graph, output:bool = false) =
  # non-wastefully adds gate by splitting an existing edge, ensuring that all gates "do something"

  assert graph.inputs.len > 0, "Graph must have inputs before adding gates"
  
  let split_output_gate_idx = rand(0 ..< graph.gates.len + graph.outputs.len)
  let is_graph_output = split_output_gate_idx >= graph.gates.len
  var split_output_gate: GateRef
  var insert_new_gate_at: int
  if is_graph_output:
    split_output_gate = graph.outputs[split_output_gate_idx - graph.gates.len]
    insert_new_gate_at = graph.gates.len
  else:
    split_output_gate = graph.gates[split_output_gate_idx]
    insert_new_gate_at = split_output_gate_idx

  var split_input_gate = sample(split_output_gate.inputs)

  var new_gate = graph.create_node()
  graph.gates.insert(new_gate, insert_new_gate_at)

  disconnect(split_input_gate, split_output_gate)
  connect(split_input_gate, new_gate)
  connect(new_gate, split_output_gate)

  let valid_gate_inputs = collect:
    for i, g in graph.gates:
      if i < insert_new_gate_at: g

  let all_valid_inputs = graph.inputs & valid_gate_inputs

  connect(sample(all_valid_inputs), new_gate)


proc new_graph_from_config(): Graph =
  var graph = Graph()

  for i in 0 ..< address_bitcount:
    graph.add_input()

  for i in 0 ..< output_bitcount:
    graph.add_output()

  for i in 0 ..< num_gates:
    graph.add_random_gate()

  graph.sort_gates()

  return graph

proc stage_function_mutation*(gate: GateRef) =
  gate.function_cache = gate.function
  let available_functions = collect:
    for f in GateFunc.low .. GateFunc.high:
      if f != gate.function: f
  gate.function = sample(available_functions)

proc undo_function_mutation*(gate: GateRef) =
  gate.function = gate.function_cache

proc stage_input_mutation*(gate: GateRef, graph: var Graph) =
  gate.inputs_cache = gate.inputs

  let random_input_choice  = rand(0..1)
  graph.refresh_descendants_until(gate)

  let valid_inputs = collect:
    for g in graph.gates:
      if not gate.descendants[g.id]: g

  let all_valid_inputs = graph.inputs & valid_inputs
  var new_input_gate = sample(all_valid_inputs)

  disconnect(gate.inputs[random_input_choice], gate)
  connect(new_input_gate, gate)

  graph.sort_gates()

proc undo_input_mutation*(gate: GateRef, graph: var Graph) =
  for i in 0..1:
    disconnect(gate.inputs[i], gate)
    connect(gate.inputs_cache[i], gate)

  graph.sort_gates()
