# import std/sequtils
import ./gate_funcs
import ./bitty
import std/sugar
import std/random
import std/sequtils
import pixie as pix

randomize()

type
  Gate = ref object
    value*: BitArray
    evaluated*: bool

    inputs*: array[2, Gate]
    inputs_cache*: array[2, Gate]

    outputs*: seq[Gate]

    function*: GateFunc
    function_cache*: GateFunc

  Graph* = object
    inputs*: seq[Gate]
    gates*: seq[Gate]
    outputs*: seq[Gate]


proc eval(gate: Gate): BitArray =
  if gate.evaluated:
    return gate.value

  else:
    # assert gate.inputs[0].evaluated and gate.inputs[1].evaluated, "Inputs must be evaluated before gate"

    gate.value = gate.function.eval(
      gate.inputs[0].eval(),
      gate.inputs[1].eval()
    )
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
    g.inputs[i] = sample(graph.inputs)
  graph.outputs.add(g)

proc add_random_gate*(graph: var Graph, lookback: int = 0) =
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

  let localized_gate_a_idx: int = min(global_gate_a_idx.int -
      graph.inputs.len.int, graph.gates.len)
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

proc uint64_to_bool_bitseq(i: uint64, bits: int): seq[bool] =
  return collect(newSeq):
    for j in 0 ..< bits:
      let mask = 1.uint64 shl j
      (i and mask) != 0

proc bool_bitseq_to_uint64(bool_bitseq: seq[bool]): uint64 =
  var output: uint64 = 0
  for i, bit in bool_bitseq:
    if bit:
      output = output or (1.uint64 shl i)
  return output

proc make_input_bitarrays*(
  height: int,
  width: int,
  channels: int,
  x_bitcount: int,
  y_bitcount: int,
  c_bitcount: int,
  pos_bitcount: int,
  ): seq[BitArray] =
  # returns seq(h*w*c)[BitArray(input_bitcount)]

  let
    y_as_bool_bitseq: seq[seq[bool]] = collect(newSeq): # seq(height)[seq(y_bitcount)]
      for y in 0 ..< height:
        y.uint64.uint64_to_bool_bitseq(bits = y_bitcount)

    x_as_bool_bitseq: seq[seq[bool]] = collect(newSeq): # seq(width)[seq(x_bitcount)]
      for x in 0 ..< width:
        x.uint64.uint64_to_bool_bitseq(bits = x_bitcount)

    c_as_bool_bitseq: seq[seq[bool]] = collect(newSeq): # seq(channels)[seq(c_bitcount)]
      for c in 0 ..< channels:
        c.uint64.uint64_to_bool_bitseq(bits = c_bitcount)

    total_iterations = width * height * channels

  var input_values: seq[seq[bool]] = newSeq[seq[bool]](
      pos_bitcount) # seq(input_bitcount)[seq(h*w*c)[bool]]
  for idx in 0 ..< total_iterations:
    let
      c: int = idx div (height * width) mod channels
      y: int = idx div (width) mod height
      x: int = idx div (1) mod width

    let
      c_bits: seq[bool] = c_as_bool_bitseq[c]
      x_bits: seq[bool] = x_as_bool_bitseq[x]
      y_bits: seq[bool] = y_as_bool_bitseq[y]

    let pos_bits: seq[bool] = x_bits & y_bits & c_bits

    for i, bit in pos_bits:
      input_values[i].add(bit)

  var input_bitarrays = newSeq[BitArray](pos_bitcount)
  for i in 0 ..< pos_bitcount:
    let bitseq = input_values[i]
    let bitarray = newBitArray(bitseq.len)
    for j, bit in bitseq:
      if bit:
        bitarray.unsafeSetTrue(j)
    input_bitarrays[i] = bitarray

  return input_bitarrays

proc unpack_bitarrays_to_uint64*(packed: seq[BitArray]): seq[uint64] =
  # seq(output_bitcount)[BitArray] --> seq(num_addresses)[uint64]
  var unpacked: seq[uint64] = newSeq[uint64](packed[0].len)
  for idx in 0 ..< packed[0].len:
    var bits: seq[bool] = newSeq[bool](packed.len)
    for i in 0 ..< packed.len:
      bits[i] = packed[i].unsafeGet(idx)
    unpacked[idx] = bool_bitseq_to_uint64(bits)

  return unpacked

proc outputs_to_pixie_image*(
  outputs: seq[uint64], # seq(num_addresses)[uint64]
  height: int,
  width: int,
  channels: int,
  ): pix.Image =

  let trimmed = outputs[0 ..< channels * height * width]
  var output_image = pix.new_image(width, height)

  for y in 0 ..< height:
    for x in 0 ..< width:
      var rgb: seq[uint8] = newSeq[uint8](3)
      for c in 0 ..< 3:
        let idx = (c * height * width) + (y * width) + x
        rgb[c] = trimmed[idx].uint8

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
  return 

proc stage_function_mutation*(gate: var Gate) =
  gate.function_cache = gate.function
  let available_functions = collect(newSeq):
    for f in GateFunc.low .. GateFunc.high:
      if f != gate.function: f
  gate.function = sample(available_functions)

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
