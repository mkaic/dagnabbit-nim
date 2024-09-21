import ./config
import ./gate_dag
import ./image_utils
import ./bitarrays

import pixie as pix

import std/strformat
import std/math

import std/strutils
import std/random
# import std/nimprof

randomize()

var input_image = pix.read_image(config.image_path)

echo "Total number of addresses: ", width * height * channels
echo "Address bitcount: ", address_bitcount
echo "Number of gates: ", num_gates

input_image = input_image.resize(width, height)
input_image.write_file("outputs/original.png")

var graph = Graph(total_nodes: address_bitcount + num_gates + output_bitcount)


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