# import std/sequtils
import ./gate_funcs
import std/sugar
import std/random
import std/bitops
import std/strutils
import std/sequtils
import pixie as pix

randomize()

type
  Gate = ref object
    value: int64
    evaluated: bool = false
    inputs: array[2, Gate]
    function: GateFunc
    function_cache: GateFunc

  Graph* = object
    inputs: seq[Gate]
    gates: seq[Gate]
    outputs: seq[Gate]
    mutated_gate: Gate

proc int64_to_binchar_seq(i: int64, bits: int): seq[char] =
  return collect(newSeq):
    for c in to_bin(i, bits): c

proc binchar_seq_to_int64(binchar_seq: seq[char]): int64 =
  return cast[int64](binchar_seq.join("").parse_bin_int())

proc eval(gate: Gate): int64 =
  if gate.evaluated:
    return gate.value

  else:
    var inputs: array[2, int64]
    for i in 0..1:
      inputs[i] = gate.inputs[i].eval()

    gate.value = gate.function.eval(inputs)
    gate.evaluated = true

    return gate.value

proc eval*(graph: var Graph, batched_inputs: seq[seq[int64]]): seq[seq[int64]] =

  var output: seq[seq[int64]]
  for batch in batched_inputs:

    for g in graph.gates:
      g.evaluated = false
    for o in graph.outputs:
      o.evaluated = false
    for i in graph.inputs:
      i.evaluated = true

    for (i, v) in zip(graph.inputs, batch):
      i.value = v

    var batch_output: seq[int64]
    for o in graph.outputs:
      batch_output.add(o.eval())
    output.add(batch_output)

  return output

proc choose_random_gate_inputs(gate: Gate, available_inputs: seq[Gate]) =
  for i in 0..1:
    gate.inputs[i] = sample(available_inputs)

proc add_input*(graph: var Graph) =
  graph.inputs.add(Gate(value: 0'i64, evaluated: true))

proc add_output*(graph: var Graph) =
  assert graph.inputs.len > 0, "Inputs must be added before outputs"
  assert graph.gates.len == 0, "Outputs must be added before gates"
  let g = Gate(value: 0'i64, evaluated: false)
  choose_random_gate_inputs(g, graph.inputs)
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
  let gate_a_idx: int = rand(graph.inputs.len ..< all_gates.len)
  var gate_a: Gate = all_gates[gate_a_idx]

  let random_input_choice: int = rand(0..<2)
  var gate_b: Gate = gate_a.inputs[random_input_choice]

  var new_gate: Gate = Gate(function: rand(GateFunc.low..GateFunc.high))

  gate_a.inputs[random_input_choice] = new_gate

  new_gate.inputs[0] = gate_b

  # This index originally referred to a location in all_gates, but I want a version
  # for just graph.gates now. So we subtract the number of inputs and clamp any indices
  # that used to refer to output-gates, since they would be larger than the length of graph.gates.
  # If an output is chosen, and there aren't any gates in graph.gates, the index will be 0.

  let localized_gate_a_idx: int = min(gate_a_idx.int - graph.inputs.len.int,
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
  # seq(h*w*c)[seq(input_bitcount)[char]] -> seq(num_batches)[seq(bitcount)[int64]]
  var num_batches: int = (unbatched.len - 1) div 64 + 1
  var batches: seq[seq[int64]]
  for batch_number in 0 ..< num_batches:
    var char_batch: seq[seq[char]] # will have shape seq(64)[seq(input_bitcount)[char]]
    for intra_batch_idx in 0 ..< 64:
      let idx: int = (batch_number * 64 + intra_batch_idx) mod unbatched.len
      let single_input: seq[char] = unbatched[idx]
      char_batch.add(single_input)

    var int64_batch: seq[int64] # will have shape seq(bitcount)[int64]
    for stack_of_bits in char_batch.transpose_2d(): # seq(input_bitcount)[seq(64)[char]]
      int64_batch.add(binchar_seq_to_int64(stack_of_bits))

    batches.add(int64_batch)
  return batches


proc unpack_int64_batches*(batched: seq[seq[int64]]): seq[seq[char]] =
  # seq(num_batches)[seq(output_bitcount)[int64]] -> seq(h*w*c)[seq(output_bitcount)[char]]
  var unbatched: seq[seq[char]] # will have shape seq(h*w*c)[seq(output_bitcount)[char]]
  for batch in batched: # seq(output_bitcount)[int64]
    var char_batch: seq[seq[char]] # will have shape seq(output_bitcount)[seq(64)[char]]
    for int64_input in batch: # int64
      char_batch.add(int64_input.int64_to_binchar_seq(bits = 64))
    unbatched &= char_batch.transpose_2d() # seq(64)[seq(output_bitcount)[char]]

  return unbatched


proc outputs_to_pixie_image*(
  outputs: seq[seq[char]], # seq(h*w*c)[seq(output_bitcount)[char]]
  height: int,
  width: int,
  ): pix.Image =

  var bytes: seq[uint8]
  for stack_of_bits in outputs:
    bytes.add(
      cast[uint8](
        binchar_seq_to_int64(stack_of_bits)
      )
    )

  var output_image = pix.new_image(width, height)

  for y in 0 ..< height:
    for x in 0 ..< width:
      var rgb: seq[uint8]
      for c in 0 ..< 3:
        let idx = (c * height * width) + (y * width) + x
        rgb.add(bytes[idx])

      output_image.unsafe[x, y] = pix.rgba(rgb[0], rgb[1], rgb[2], 255)

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


proc stage_mutation*(graph: var Graph) =
  let available_gates = graph.gates & graph.outputs
  graph.mutated_gate = sample(available_gates)

  graph.mutated_gate.function_cache = graph.mutated_gate.function
  graph.mutated_gate.function = rand(GateFunc.low..GateFunc.high)

proc undo_mutation*(graph: var Graph) =
  graph.mutated_gate.function = graph.mutated_gate.function_cache
