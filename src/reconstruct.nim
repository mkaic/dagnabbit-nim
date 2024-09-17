import ./gate_dag
import pixie as pix
import std/strformat
import std/math
import std/bitops
import std/strutils
import std/random

randomize()

var branos = pix.read_image("loss.jpg")

const
  width = 35
  height = 45
  channels = 3

  x_bitcount = fast_log2(width) + 1
  y_bitcount = fast_log2(height) + 1
  c_bitcount = fast_log2(channels) + 1
  input_bitcount = x_bitcount + y_bitcount + c_bitcount
  output_bitcount = 8
  num_gates = 2048
  lookback = num_gates div 2
  improvement_deque_len = 50

echo x_bitcount
echo y_bitcount
echo c_bitcount
echo input_bitcount

branos = branos.resize(width, height)
branos.write_file("original.png")

var graph = Graph()

for i in 0 ..< input_bitcount:
  graph.add_input()

for i in 0 ..< output_bitcount:
  graph.add_output()

for i in 0 ..< num_gates:
  discard graph.add_random_gate(lookback = lookback)

var error = 255.0
var improved: seq[int8]

let inputs: seq[seq[char]] = make_inputs(
  height = height,
  width = width,
  channels = channels,
  x_bitcount = x_bitcount,
  y_bitcount = y_bitcount,
  c_bitcount = c_bitcount,
  pos_bitcount = input_bitcount
  )

let bitpacked_inputs = pack_int64_batches(
  unbatched = inputs,
  bitcount = input_bitcount
)

type MutationType = enum mt_FUNCTION, mt_INPUT

var improvement_counter: int = 0
for i in 1..50_000:
  var random_gate = graph.select_random_gate()
  let mutation_type = rand(MutationType.low..MutationType.high)
  case mutation_type
  of mt_FUNCTION:
    random_gate.stage_function_mutation()
  of mt_INPUT:
    random_gate.stage_input_mutation(graph, lookback)

  let bitpacked_outputs: seq[seq[int64]] = graph.eval(bitpacked_inputs)
  let outputs: seq[seq[char]] = unpack_int64_batches(bitpacked_outputs)

  let output_image = outputs_to_pixie_image(
    outputs,
    height = height,
    width = width,
    channels = channels
    )

  let candidate_error = calculate_mae(branos, output_image)
  if candidate_error < error:

    error = candidate_error
    improved.add(1)

    let improvement_rate = math.sum[int8](improved).float64 /
        improved.len.float64
    echo &"Error: {error:0.3f} at step {i}. Improvement rate: {improvement_rate:0.5f}, Mutation type: {mutation_type}"

    let resized = output_image.resize(width*8, height*8)
    resized.write_file(&"outputs/{improvement_counter:06}.png")
    improvement_counter += 1
    resized.write_file(&"latest.png")

  elif candidate_error == error:
    improved.add(0)
  else:
    improved.add(0)
    case mutation_type
    of mt_FUNCTION:
      random_gate.undo_function_mutation()
    of mt_INPUT:
      random_gate.undo_input_mutation()

  if improved.len > improvement_deque_len:
    improved.delete(0)


