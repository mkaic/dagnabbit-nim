import ./gate_dag
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
  width = 16
  height = 24
  channels = 3

  x_bitcount = fast_log2(width) + 1
  y_bitcount = fast_log2(height) + 1
  c_bitcount = fast_log2(channels) + 1
  input_bitcount = x_bitcount + y_bitcount + c_bitcount
  output_bitcount = 8
  num_gates = 256
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
  graph.add_random_gate()

let input_bitarrays: seq[BitArray] = make_input_bitarrays(
  height = height,
  width = width,
  channels = channels,
  x_bitcount = x_bitcount,
  y_bitcount = y_bitcount,
  c_bitcount = c_bitcount,
  pos_bitcount = input_bitcount
  )

var global_best_rmse = 255'f32
var improvement_count = 0
for i in 0..50_000:
  var random_gate = graph.gates.sample()
  random_gate.stage_input_mutation(graph)
  random_gate.stage_function_mutation()

  let output_bitarrays: seq[BitArray] = graph.eval(input_bitarrays)
  let output_unpacked = unpack_bitarrays_to_uint64(output_bitarrays)

  let output_image = outputs_to_pixie_image(
    output_unpacked,
    height = height,
    width = width,
    channels = channels
    )

  let rmse = calculate_rmse(input_image, output_image)

  if rmse < global_best_rmse:
    global_best_rmse = rmse
    improvement_count += 1
    
    echo &"RMSE: {global_best_rmse:.4f} at step {i:06}"
    
    let resized = output_image.resize(width*8, height*8)
    resized.write_file(&"outputs/timelapse/{improvement_count:06}.png")
    resized.write_file("outputs/latest.png")

  elif rmse == global_best_rmse:
    discard # Keep the mutation, but don't count it as an improvement
  else:
    random_gate.undo_input_mutation()
    random_gate.undo_function_mutation()