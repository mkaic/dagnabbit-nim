import ./gate_dag
import ./gate_funcs
import ./image_utils
import ./bitty

import pixie as pix

import std/strformat
import std/math
import std/bitops
import std/strutils
import std/random
# import std/nimprof

randomize()

var input_image = pix.read_image("test_images/mona_lisa.jpg")

const
  width = 128
  height = 192
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

graph.kahn_topo_sort()

let input_bitarrays: seq[BitArray] = make_bitpacked_addresses(
  height = height,
  width = width,
  channels = channels,
  )

var global_best_rmse = 255'f32
var global_best_image: pix.Image
var timelapse_count = 0
var round = 0
for i in 0..100_000:
  let gate_idx = i mod (graph.gates.len + graph.outputs.len)
  if gate_idx == 0:
    round += 1

  var mutated_gate: GateRef
  if gate_idx >= graph.gates.len:
    mutated_gate = graph.outputs[gate_idx - graph.gates.len]
  else:
    mutated_gate = graph.gates[gate_idx]
  
  var local_best_rmse = 255'f32
  for gate_func in GateFunc:
    mutated_gate.function = gate_func

    let output_bitarrays: seq[BitArray] = graph.eval(input_bitarrays)
    let output_unpacked = unpack_bitarrays_to_uint64(output_bitarrays)

    let output_image = outputs_to_pixie_image(
      output_unpacked,
      height = height,
      width = width,
      channels = channels
      )

    let rmse = calculate_rmse(input_image, output_image)

    if rmse < local_best_rmse:
      local_best_rmse = rmse
      mutated_gate.function_cache = gate_func

    if local_best_rmse < global_best_rmse:
      global_best_rmse = local_best_rmse
      global_best_image = output_image
    
      echo &"RMSE: {global_best_rmse:.4f}. Step {i:06}. Round {round:04}."

      output_image.write_file(&"outputs/timelapse/{timelapse_count:06}.png")
      output_image.write_file("outputs/latest.png")
      timelapse_count += 1

  mutated_gate.function = mutated_gate.function_cache