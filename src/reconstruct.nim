import ./gate_dag
import ./gate_funcs
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

  x_bitcount = fast_log2(width) + 1
  y_bitcount = fast_log2(height) + 1
  c_bitcount = fast_log2(channels) + 1
  input_bitcount = x_bitcount + y_bitcount + c_bitcount
  output_bitcount = 8
  num_gates = 256
  lookback = 0
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

let input_bitarrays: seq[BitArray] = make_input_bitarrays(
  height = height,
  width = width,
  channels = channels,
  x_bitcount = x_bitcount,
  y_bitcount = y_bitcount,
  c_bitcount = c_bitcount,
  pos_bitcount = input_bitcount
  )



for i in 0..50_000:

  var output_image: pix.Image

  var random_gate: GateRef = sample(graph.gates)

  let output_bitarrays: seq[BitArray] = graph.eval(input_bitarrays)
  let output_unpacked = unpack_bitarrays_to_uint64(output_bitarrays)

  output_image = outputs_to_pixie_image(
    output_unpacked,
    height = height,
    width = width,
    channels = channels
    )

  var rmse = calculate_rmse(input_image, output_image)

  var best_func = random_gate.function

  for gate_func in GateFunc:
    if gate_func == random_gate.function:
      continue
    random_gate.function = gate_func

    let output_bitarrays: seq[BitArray] = graph.eval(input_bitarrays)
    let output_unpacked = unpack_bitarrays_to_uint64(output_bitarrays)

    output_image = outputs_to_pixie_image(
      output_unpacked,
      height = height,
      width = width,
      channels = channels
      )

    let candidate_rmse = calculate_rmse(input_image, output_image)
    if candidate_rmse < rmse:
      rmse = candidate_rmse
      best_func = gate_func

  random_gate.function = best_func

  echo &"RMSE: {rmse:.4f} at step {i:06}. Best function: {best_func}"

  if i mod 100 == 0:
    let resized = output_image.resize(width*8, height*8)
    resized.write_file(&"outputs/timelapse/{i:06}.png")
    resized.write_file("outputs/latest.png")