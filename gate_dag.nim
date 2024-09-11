# import std/sequtils
import std/sugar
import std/random
import std/bitops
import std/strutils
import std/sequtils
import pixie as pix

randomize()

type
  Gate* = ref object
    value: int64
    evaluated: bool
    inputs: array[2, Gate]

  Graph* = object
    inputs: seq[Gate]
    gates*: seq[Gate]
    outputs: seq[Gate]

proc evaluate_gate*(gate: Gate): int64 =
  if not gate.evaluated:
    gate.value = bit_not(
      bit_and(
        gate.inputs[0].evaluate_gate(),
        gate.inputs[1].evaluate_gate()
      )
    )
    gate.evaluated = true

  return gate.value

proc evaluate_graph*(self: var Graph): seq[int64] =
  return collect(newSeq):
    for o in self.outputs:
      o.evaluate_gate()

proc reset*(graph: var Graph) =
  for g in graph.gates:
    g.evaluated = false
  for g in graph.outputs:
    g.evaluated = false

proc add_inputs*(graph: var Graph, n: int) =
  for _ in 0 ..< n:
    graph.inputs.add(Gate(value: 0'i64, evaluated: true))


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

proc init_gates*(
  graph: var Graph,
  num_gates: int,
  last: int = 0,
  output: bool = false
  ) =

  var available_graph_inputs = graph.inputs & graph.gates

  if last > 0 and graph.gates.len >= last:
    available_graph_inputs = available_graph_inputs[^last..^1]

  for _ in 0 ..< num_gates:
    var gate_inputs: array[2, Gate]
    for i in 0..1:
      gate_inputs[i] = available_graph_inputs[rand(available_graph_inputs.len - 1)]

    var g = Gate(inputs: gate_inputs)

    if output:
      graph.outputs.add(g)
    else:
      graph.gates.add(g)

proc set_inputs*(graph: var Graph, input_values: seq[int64]) =
  for i, v in input_values:
    graph.inputs[i].value = v

func int64_to_binchar_seq(i: int64, bits: int): seq[char] =
  return collect(newSeq):
    for c in to_bin(i, bits): c

func binchar_seq_to_int64(binchar_seq: seq[char]): int64 =
  return cast[int64](binchar_seq.join("").parse_bin_int())

func transpose[T](matrix: seq[seq[T]]): seq[seq[T]] =
  let rowsize = matrix[0].len

  return collect(newSeq):
    for i in 0 ..< rowsize:
      collect(newSeq):
        for row in matrix:
          row[i]

func make_bitpacked_int64_batches*(
  height: int,
  width: int,
  channels: int
  ): (seq[seq[int64]], int) =

  let
    x_bitcount = fast_log_2(width) + 1
    y_bitcount = fast_log_2(height) + 1
    c_bitcount = fast_log_2(channels) + 1
    pos_bitcount = x_bitcount + y_bitcount + c_bitcount

    y_as_bits = collect(newSeq):
      for y in 0 ..< height:
        y.int64_to_binchar_seq(bits = y_bitcount)

    x_as_bits = collect(newSeq):
      for x in 0 ..< width:
        x.int64_to_binchar_seq(bits = x_bitcount)

    c_as_bits = collect(newSeq):
      for c in 0 ..< channels:
        c.int64_to_binchar_seq(bits = c_bitcount)

    total_iterations = width * height * channels
    batch_count = (total_iterations + 1) div 64

  var batches: seq[seq[int64]]
  for batch_idx in 0 ..< batch_count:

    var batch_of_pos_bits: seq[seq[char]]
    for i in 0 ..< 64:
      # it's alright if c, y, or x are out of bounds because they are moduloed, so they'll
      # just wrap around to the beginning again, meaning any extra work done will just be
      # duplicate work on the first few pixels
      let
        idx = batch_idx * 64 + i
        c = idx div (height * width) mod channels
        y = idx div (width) mod height
        x = idx div (1) mod width

        x_bits = x_as_bits[x]
        y_bits = y_as_bits[y]
        c_bits = c_as_bits[c]

      batch_of_pos_bits.add(x_bits & y_bits & c_bits)

    let batch: seq[int64] = collect(newSeq):
      for bits in batch_of_pos_bits.transpose():
        bits.binchar_seq_to_int64()

    batches.add(batch)

  return (batches, pos_bitcount)

func concat_seqs[T](seqs: seq[seq[T]]): seq[T] =
  return collect(newSeq):
    for s in seqs:
      for e in s: e

func unpack_int64_outputs_to_pixie*(
  outputs: seq[seq[int64]], # seq(batches)[seq(8)[int64]]
  height: int,
  width: int,
  channels: int
  ): pix.Image =

  let as_binchar_seqs = collect(newSeq):
    for t in outputs:
      collect(newSeq):
        for b in t:
          b.int64_to_binchar_seq(bits = 64) # seq(batches)[seq(8)[seq(64)[char]]]

  let batch_by_64_by_8 = as_binchar_seqs.map(transpose) # seq(batches)[seq(64)[seq(8)[char]]]
  let flattened = batch_by_64_by_8.concat_seqs() # seq(num_pixels)[seq(8)[char]]
  let as_uint8 = collect(newSeq):
    for f in flattened:
      cast[uint8](f.binchar_seq_to_int64())

  var output_image = pix.new_image(width, height)

  for y in 0 ..< height:
    for x in 0 ..< width:
      let rgb = collect(newSeq):
        for c in 0 ..< channels:
          let idx = (c * height * width) + (y * width) + x
          as_uint8[idx]
      output_image.unsafe[x, y] = pix.rgba(rgb[0], rgb[1], rgb[2], 255)

  return output_image

func calculate_mae*(
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


proc stage_mutation*(graph: var Graph, last: int): (Gate, array[2, Gate]) =
  let available_gates = graph.gates & graph.outputs
  let random_idx = rand(0..<available_gates.len)
  var g = available_gates[random_idx]

  let total_idx = (graph.inputs.len - 1) + random_idx
  var available_inputs = graph.inputs & graph.gates & graph.outputs
  # echo ""
  # echo available_inputs.len
  # echo total_idx
  # echo graph.inputs.len - 1
  # echo random_idx

  available_inputs = available_inputs[0..<total_idx]

  if last > 0 and available_inputs.len >= last:
    available_inputs = available_inputs[^last..^1]

  let old_inputs = g.inputs
  for i in 0..1:
    g.inputs[i] = available_inputs[rand(available_inputs.len - 1)]

  return (g, old_inputs)

proc undo_mutation*(gate: Gate, old_inputs: array[2, Gate]) =
  for i in 0..1:
    gate.inputs[i] = old_inputs[i]
