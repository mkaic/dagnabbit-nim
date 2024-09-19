import ./gate_dag
import ./image_utils
import ./bitty

import pixie as pix

import std/strformat
import std/math
import std/bitops
import std/strutils
import std/random

randomize()

var input_image = pix.read_image("test_images/mona_lisa.jpg")

const
  width = 32
  height = 48
  channels = 3
  output_bitcount = 8
  num_gates = 1024
  address_bitcount = fast_log2(width * height * channels) + 1

echo "Total number of addresses: ", width * height * channels
echo "Address bitcount: ", address_bitcount
echo "Number of gates: ", num_gates

input_image = input_image.resize(width, height)
input_image.write_file("outputs/original.png")

var graph = Graph()

for i in 0 ..< address_bitcount:
  graph.add_input()

for i in 0 ..< output_bitcount:
  graph.add_output()

for i in 0 ..< num_gates:
  graph.add_random_gate()

let input_bitarrays: seq[BitArray] = make_bitpacked_addresses(
  height = height,
  width = width,
  channels = channels,
  )

type MutationType = enum
  mt_FUNCTION,
  mt_INPUT

var global_best_rmse = 255'f32
var global_best_image: pix.Image
var timelapse_count = 0
var round = 0
for i in 0..100_000:

  let gate_idx = i mod (graph.gates & graph.outputs).len
  if gate_idx == 0:
    round += 1
  var random_gate = (graph.gates & graph.outputs)[gate_idx]

  let mutation_type = rand(MutationType.low..MutationType.high)
  case mutation_type:
    of mt_FUNCTION:
      random_gate.stage_function_mutation()
    of mt_INPUT:
      random_gate.stage_input_mutation(graph)

  let output_bitarrays: seq[BitArray] = graph.eval(input_bitarrays)
  let output_unpacked = unpack_bitarrays_to_uint64(output_bitarrays)

  let output_image = outputs_to_pixie_image(
    output_unpacked,
    height = height,
    width = width,
    channels = channels
    )

  let rmse = calculate_rmse(input_image, output_image)

  if i mod 100 == 0:
    output_image.write_file(&"outputs/timelapse/{timelapse_count:06}.png")
    output_image.write_file("outputs/latest.png")
    timelapse_count += 1

  if rmse < global_best_rmse:
    global_best_rmse = rmse
    global_best_image = output_image
    echo &"RMSE: {global_best_rmse:.4f} at step {i:06}. Round: {round}"#. Mutation type: {mutation_type}"

  elif rmse == global_best_rmse:
    discard # Keep the mutation, but don't count it as an improvement
  
  else:
    case mutation_type:
      of mt_FUNCTION:
        random_gate.undo_function_mutation()
      of mt_INPUT:
        random_gate.undo_input_mutation()