import ./gate_dag
import ./image_utils
import ./bitty

import pixie as pix

import std/strformat
import std/sequtils
import std/math
import std/bitops
import std/strutils
import std/random
# import std/nimprof

randomize()

var input_image = pix.read_image("test_images/branos.png")

const
  width = 64
  height = 64
  channels = 3
  output_bitcount = 8
  num_gates = 256
  rounds = 1024
  address_bitcount = fast_log2(width * height * channels) + 1

echo "Total number of addresses: ", width * height * channels
echo "Address bitcount: ", address_bitcount
echo "Number of gates: ", num_gates

input_image = input_image.resize(width, height)
input_image.write_file("outputs/original.png")

var graph = Graph(total_nodes: address_bitcount + num_gates + output_bitcount)

for i in 0 ..< address_bitcount:
  graph.add_input()

for i in 0 ..< output_bitcount:
  graph.add_output()

for i in 0 ..< num_gates:
  graph.add_random_gate()

graph.sort_gates()

let input_bitarrays: seq[BitArray] = make_bitpacked_addresses(
  height = height,
  width = width,
  channels = channels,
  )

var global_best_rmse = 255'f32
var global_best_image: pix.Image
var timelapse_count = 0
var last_saved_at = global_best_rmse

type MutationType = enum 
  # mt_INPUT, 
  mt_FUNCTION

for round in 0 ..< rounds:

  var permutation = graph.gates & graph.outputs
  permutation.shuffle()

  for i, mutated_gate in permutation:

    let step = i + round * permutation.len

    let mutation_type = rand(MutationType.low .. MutationType.high)
    case mutation_type
      # of mt_INPUT:
      #   stage_input_mutation(mutated_gate, graph)
      of mt_FUNCTION:
        stage_function_mutation(mutated_gate)
    
    var output_image: pix.Image

    let output_bitarrays: seq[BitArray] = graph.eval(input_bitarrays)
    let output_unpacked = unpack_bitarrays_to_uint64(output_bitarrays)

    output_image = outputs_to_pixie_image(
      output_unpacked,
      height = height,
      width = width,
      channels = channels
      )

    let rmse = calculate_rmse(input_image, output_image)

    if rmse < global_best_rmse:
      global_best_rmse = rmse
      global_best_image = output_image
      echo &"RMSE: {global_best_rmse:.4f}. Step {step:06}. Round {round:04}. Last saved at {last_saved_at:.4f}."

    elif rmse == global_best_rmse:
      discard

    else:
      case mutation_type
        # of mt_INPUT:
        #   undo_input_mutation(mutated_gate, graph)
        of mt_FUNCTION:
          undo_function_mutation(mutated_gate)

    if rmse < (last_saved_at * 0.99):
      last_saved_at = rmse
      output_image.write_file(&"outputs/timelapse/{timelapse_count:06}.png")
      output_image.write_file("outputs/latest.png")
      timelapse_count += 1
      # echo &"Saved timelapse image."

    # if step mod 100 == 0:
    #   echo &"Step {step:06}. Round {round:04}."