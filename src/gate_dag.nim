# import std/sequtils
import ./gate_funcs
import ./bitty
import std/sugar
import std/random
import std/strutils
import std/sequtils
import pixie as pix

randomize()

type
  Gate = ref object
    value: BitArray
    evaluated: bool = false
    inputs: array[2, Gate]
    inputs_cache: array[2, Gate]
    function: GateFunc
    function_cache: GateFunc

  Graph* = object
    inputs: seq[Gate]
    gates: seq[Gate]
    outputs: seq[Gate]
    mutated_gate: Gate

proc eval(gate: Gate): BitArray =
  if gate.evaluated:
    return gate.value

  else:
    var inputs: seq[BitArray]
    for i in 0..1:
      inputs.add(gate.inputs[i].eval())

    gate.value = gate.function.eval(inputs[0], inputs[1])
    gate.evaluated = true

    return gate.value

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

  for o in graph.outputs:
    output.add(o.eval())

  return output

proc add_input*(graph: var Graph) =
  graph.inputs.add(Gate(evaluated: true))

proc add_output*(graph: var Graph) =
  assert graph.inputs.len > 0, "Inputs must be added before outputs"
  assert graph.gates.len == 0, "Outputs must be added before gates"
  let g = Gate(evaluated: false)
  for i in 0..1:
    g.inputs[i] = sample(graph.gates)
  graph.outputs.add(g)

proc add_random_gate*(
  graph: var Graph,
  lookback: int = 0,
  ): int =
  # we split an edge between two existing gates with a new gate
  # but this leaves one undetermined input on the new gate. This
  # input is chosen randomly from gates before the new gate in
  # the graph.

  let all_gates: seq[Gate] = graph.inputs & graph.gates & graph.outputs
  let global_gate_a_idx: int = rand(graph.inputs.len ..< all_gates.len)
  var gate_a: Gate = all_gates[global_gate_a_idx]

  let random_input_choice: int = rand(0..<2)
  var gate_b: Gate = gate_a.inputs[random_input_choice]

  var new_gate: Gate = Gate(function: rand(GateFunc.low..GateFunc.high))

  gate_a.inputs[random_input_choice] = new_gate

  new_gate.inputs[0] = gate_b

  # This index originally referred to a location in all_gates, but I want a version
  # for just graph.gates now. So we subtract the number of inputs and clamp any indices
  # that used to refer to output-gates, since they would be larger than the length of graph.gates.
  # If an output is chosen, and there aren't any gates in graph.gates, the index will be 0.

  let localized_gate_a_idx: int = min(global_gate_a_idx.int - graph.inputs.len.int,
      graph.gates.len)
  var gate_c_options: seq[Gate]
  if graph.gates.len > 0:
    var gate_c_localized_idx_lower: int
    if lookback > 0:
      gate_c_localized_idx_lower = max(0, localized_gate_a_idx.int - lookback.int)
    else:
      gate_c_localized_idx_lower = 0

    gate_c_options = graph.inputs & graph.gates[gate_c_localized_idx_lower ..< localized_gate_a_idx]

  else:
    gate_c_options = graph.inputs

  let gate_c = sample(gate_c_options)

  new_gate.inputs[1] = gate_c

  graph.gates.insert(new_gate, localized_gate_a_idx)

  return localized_gate_a_idx

proc int64_to_binchar_seq(i: int64, bits: int): seq[char] =
  return collect(newSeq):
    for c in to_bin(i, bits): c

proc binchar_seq_to_int64(binchar_seq: seq[char]): int64 =
  return cast[int64](binchar_seq.join("").parse_bin_int())

proc make_inputs*(
  height: int,
  width: int,
  channels: int,
  x_bitcount: int,
  y_bitcount: int,
  c_bitcount: int,
  pos_bitcount: int,
  ): seq[seq[char]] =
  # returns seq(h*w*c)[seq(input_bitcount)[char]]

  let
    y_as_bits: seq[seq[char]] = collect(newSeq):
      for y in 0 ..< height:
        y.int64_to_binchar_seq(bits = y_bitcount)

    x_as_bits: seq[seq[char]] = collect(newSeq):
      for x in 0 ..< width:
        x.int64_to_binchar_seq(bits = x_bitcount)

    c_as_bits: seq[seq[char]] = collect(newSeq):
      for c in 0 ..< channels:
        c.int64_to_binchar_seq(bits = c_bitcount)

    total_iterations = width * height * channels

  var input_values: seq[seq[char]]
  for idx in 0 ..< total_iterations:
    let
      c: int = idx div (height * width) mod channels
      y: int = idx div (width) mod height
      x: int = idx div (1) mod width

    let
      c_bits: seq[char] = c_as_bits[c]
      x_bits: seq[char] = x_as_bits[x]
      y_bits: seq[char] = y_as_bits[y]

    let pos_bits: seq[char] = x_bits & y_bits & c_bits
    input_values.add(pos_bits)
  return input_values

proc transpose_2d[T](matrix: seq[seq[T]]): seq[seq[T]] =
  let
    dim0: int = matrix.len
    dim1: int = matrix[0].len

  var transposed: seq[seq[T]]
  for i in 0 ..< dim1:
    var row: seq[T]
    for j in 0 ..< dim0:
      row.add(matrix[j][i])
    transposed.add(row)
  return transposed

proc pack_int64_batches*(unbatched: seq[seq[char]], bitcount: int): seq[seq[int64]] =
  # seq(h*w*c)[seq(input_bitcount)[char]] --> seq(bitcount)[seq(num_batches)[int64]]
  var num_batches: int = (unbatched.len - 1) div 64 + 1
  # will have shape seq(bitcount)[seq(num_batches)[int64]]
  var batched: seq[seq[int64]]

  for batch_number in 0 ..< num_batches:
    var char_batch: seq[seq[char]] # will have shape seq(64)[seq(input_bitcount)[char]]
    for intra_batch_idx in 0 ..< 64:
      let idx: int = (batch_number * 64 + intra_batch_idx) mod unbatched.len
      let single_input: seq[char] = unbatched[idx]
      char_batch.add(single_input)

    var int64_batch: seq[int64] # will have shape seq(bitcount)[int64]
    for stack_of_bits in char_batch.transpose_2d(): # seq(input_bitcount)[seq(64)[char]]
      int64_batch.add(binchar_seq_to_int64(stack_of_bits))

    if batched.len == 0:
      for i in 0..<bitcount:
        batched.add(@[int64_batch[i]])
    else:
      for i in 0..<bitcount:
        batched[i] &= int64_batch[i]

  return batched


proc unpack_int64_batches*(batched: seq[seq[int64]]): seq[seq[char]] =
  # seq(output_bitcount)[seq(num_batches)[int64]] --> seq(num_batches * 64)[seq(output_bitcount)[char]]
  var unbatched: seq[seq[char]] # seq(output_bitcount)[seq(num_batches * 64)[char]]
  for bit_column in batched: # seq(num_batches)[int64]

    # will have shape seq(num_batches * 64)[char]
    var char_batch: seq[char]
    for int64_input in bit_column: # int64
      char_batch &= int64_input.int64_to_binchar_seq(bits = 64)

    unbatched.add(char_batch)

  return unbatched.transpose_2d() # seq(num_batches * 64)[seq(output_bitcount)[char]]

proc outputs_to_pixie_image*(
  outputs: seq[seq[char]], # seq(num_batches * 64)[seq(output_bitcount)[char]]
  height: int,
  width: int,
  channels: int,
  ): pix.Image =

  let trimmed = outputs[0 ..< channels * height * width]
  var bytes: seq[uint8]
  for binchar_byte in trimmed:
    bytes.add(
      cast[uint8](
        binchar_seq_to_int64(binchar_byte)
      )
    )

  var output_image = pix.new_image(width, height)

  for y in 0 ..< height:
    for x in 0 ..< width:
      var rgb: seq[uint8]
      for c in 0 ..< 3:
        let idx = (c * height * width) + (y * width) + x
        rgb.add(bytes[idx])

      output_image.unsafe[x, y] = pix.rgbx(rgb[0], rgb[1], rgb[2], 255)

  return output_image

proc calculate_mae*(
  image1: pix.Image,
  image2: pix.Image
  ): float64 =

  var error = 0
  for y in 0 ..< image1.height:
    for x in 0 ..< image1.width:
      let rgb1 = image1.unsafe[x, y]
      let rgb2 = image2.unsafe[x, y]
      error += abs(rgb1.r.int - rgb2.r.int)
      error += abs(rgb1.g.int - rgb2.g.int)
      error += abs(rgb1.b.int - rgb2.b.int)

  return error.float64 / (image1.width.float64 * image1.height.float64 * 3.0)

proc select_random_gate*(graph: Graph): Gate =
  return sample(graph.gates & graph.outputs)

proc stage_function_mutation*(gate: var Gate) =
  gate.function_cache = gate.function
  gate.function = rand(GateFunc.low..GateFunc.high)

proc undo_function_mutation*(gate: var Gate) =
  gate.function = gate.function_cache

proc stage_input_mutation*(gate: var Gate, graph: Graph, lookback: int) =
  gate.inputs_cache = gate.inputs
  let gate_idx: int = graph.gates.find(gate)
  var available_inputs: seq[Gate]
  if lookback > 0 and gate_idx > lookback:
    available_inputs = graph.inputs & graph.gates[gate_idx - lookback ..< gate_idx]
  elif gate_idx > 0:
    available_inputs = graph.inputs & graph.gates[0 ..< gate_idx]
  else:
    available_inputs = graph.inputs

  for i in 0..1:
    gate.inputs[i] = sample(available_inputs)

proc undo_input_mutation*(gate: var Gate) =
  gate.inputs = gate.inputs_cache