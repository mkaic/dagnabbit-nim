# import std/sequtils
import std/sugar
import std/random
import std/bitops

randomize()

type
  Gate = ref object
    value: uint64
    evaluated: bool
    inputs: array[2, Gate]
    outputs: seq[Gate]

  Graph* = object
    inputs: seq[Gate]
    gates: seq[Gate]
    outputs: seq[Gate]

proc evaluate_gate*(gate: Gate): uint64 =
  if not gate.evaluated:
    gate.value = bit_not(
      bit_and(
        gate.inputs[0].evaluate_gate(), 
        gate.inputs[1].evaluate_gate()
      )
    )
    gate.evaluated = true

  return gate.value

proc evaluate_graph*(self: var Graph): seq[uint64] =
  return collect(newSeq):
    for o in self.outputs:
      o.evaluate_gate()

proc reset*(graph: var Graph) =
  for g in graph.gates:
    g.evaluated = false
  for g in graph.outputs:
    g.evaluated = false

proc add_input*(graph: var Graph) =
  graph.inputs.add(Gate(value: 0'u64, evaluated: true))


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

proc set_inputs*(graph: var Graph, input_values: seq[uint64]) =
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

proc transpose_bitmatrix*(matrix: seq[seq[bool]]): seq[seq[bool]] =
  let rowsize = matrix[0].len

  return collect(newSeq):
    for i in 0 ..< rowsize:
      collect(newSeq):
        for row in matrix:
          row[i]

proc make_bitpacked_uint64_batches*(height: int, width: int, channels: int): (seq[seq[uint64]], int) =

  let
    x_bitcount = fast_log_2(width) + 1
    y_bitcount = fast_log_2(height) + 1
    c_bitcount = fast_log_2(channels) + 1
    pos_bitcount = x_bitcount + y_bitcount + c_bitcount

    y_as_bits = collect(newSeq):
      for y in 0 ..< height:
        y.int_to_bool_seq(bits=y_bitcount)

    x_as_bits = collect(newSeq):
      for x in 0 ..< width:
        x.int_to_bool_seq(bits=x_bitcount)

    c_as_bits = collect(newSeq):
      for c in 0 ..< channels:
        c.int_to_bool_seq(bits=c_bitcount)

    total_iterations = width * height * channels
    batch_count = (total_iterations + 1) div 64

  var batches: seq[seq[uint64]]
  for batch_idx in 0 ..< batch_count:

    var batch_of_pos_bits: seq[seq[bool]]
    for i in 0 ..< 64:
      let
        idx = batch_idx * 64 + i
        c = idx div (height * width) mod channels
        y = idx div (width) mod height
        x = idx div (1) mod width

        x_bits = x_as_bits[x]
        y_bits = y_as_bits[y]
        c_bits = c_as_bits[c]

      batch_of_pos_bits.add(x_bits & y_bits & c_bits)

    let batch: seq[uint64] = collect(newSeq):
      for bits in batch_of_pos_bits.transpose_bitmatrix():
        cast[uint64](bits.bool_seq_to_int()) 

    batches.add(batch)

  return (batches, pos_bitcount)

proc init_as_reconstructor*(graph: var Graph, input_size: int, output_size: int, num_gates: int) =
  for i in 0 ..< input_size:
    graph.add_input()

  for i in 0 ..< num_gates:
    graph.init_gate()

  for i in 0 ..< output_size:
    graph.init_gate(output = true)