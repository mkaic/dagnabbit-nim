import ./gate_dag
import ./bitty

import pixie as pix

import std/strformat
import std/math
import std/bitops
import std/strutils
import std/random

randomize()

var input_image = pix.read_image("test_images/branos.png")

const
  width = 64
  height = 64
  channels = 3

  x_bitcount = fast_log2(width) + 1
  y_bitcount = fast_log2(height) + 1
  c_bitcount = fast_log2(channels) + 1
  input_bitcount = x_bitcount + y_bitcount + c_bitcount
  output_bitcount = 8
  num_gates = 2048
  lookback = num_gates div 2
  improvement_deque_len = 100
  num_addresses = width * height * channels

echo "Width address bitcount: ", x_bitcount
echo "Height address bitcount: ", y_bitcount
echo "Channel address bitcount: ", c_bitcount
echo "Total address bitcount: ", input_bitcount
echo "Total number of addresses: ", num_addresses
echo "Number of gates: ", num_gates

input_image = input_image.resize(width, height)
input_image.write_file("outputs/original.png")

var graph = Graph()

for i in 0 ..< input_bitcount:
  graph.add_input()

for i in 0 ..< output_bitcount:
  graph.add_output()

for i in 0 ..< num_gates:
  graph.add_random_gate(lookback = lookback)

var error = 255.0
var improved: seq[int8]

let input_bitarrays: seq[BitArray] = make_input_bitarrays(
  height = height,
  width = width,
  channels = channels,
  x_bitcount = x_bitcount,
  y_bitcount = y_bitcount,
  c_bitcount = c_bitcount,
  pos_bitcount = input_bitcount
  )

type MutationType = enum 
  mt_FUNCTION,
  mt_INPUT

var improvement_counter: int = 0
for i in 1..50_000:
  if improved.len > improvement_deque_len:
    improved.delete(0)

  var random_gate = sample(graph.gates & graph.outputs)
  let mutation_type = rand(MutationType.low..MutationType.high)
  case mutation_type
  of mt_FUNCTION:
    random_gate.stage_function_mutation()
  of mt_INPUT:
    random_gate.stage_input_mutation(graph, lookback)

  let output_bitarrays: seq[BitArray] = graph.eval(input_bitarrays)
  let output_unpacked = unpack_bitarrays_to_uint64(output_bitarrays)

  let output_image = outputs_to_pixie_image(
    output_unpacked,
    height = height,
    width = width,
    channels = channels
    )

  let candidate_error = calculate_mae(input_image, output_image)
  if candidate_error < error:

    error = candidate_error
    improved.add(1)

    let improvement_rate = math.sum[int8](improved).float64 /
        improved.len.float64 * 100.0
    echo &"Error: {error:.4f} at step {i:06}. Improvement rate: {improvement_rate:.2f}, Mutation type: {mutation_type}"

    let resized = output_image.resize(width*8, height*8)
    resized.write_file(&"outputs/timelapse/{improvement_counter:06}.png")
    improvement_counter += 1
    resized.write_file("outputs/latest.png")

  elif candidate_error == error:
    improved.add(0)
  else:
    improved.add(0)
    case mutation_type
    of mt_FUNCTION:
      random_gate.undo_function_mutation()
    of mt_INPUT:
      random_gate.undo_input_mutation()