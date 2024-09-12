import ./gate_dag
import pixie as pix
import std/strformat
import std/math
import std/bitops

var branos = pix.read_image("branos.png")

const
  width = 32
  height = 32
  channels = 3

  x_bitcount = fast_log2(width) + 1
  y_bitcount = fast_log2(height) + 1
  c_bitcount = fast_log2(channels) + 1
  input_bitcount = x_bitcount + y_bitcount + c_bitcount
  output_bitcount = 8

  num_gates = 1024
  lookback = 32
  improvement_deque_len = 50

branos = branos.resize(width, height)

var graph = Graph()

for i in 0 ..< input_bitcount:
  graph.add_input()
for i in 0 ..< output_bitcount:
  graph.add_output()
for i in 0 ..< num_gates:
  graph.add_random_gate(lookback = lookback)


echo &"Graph has {graph.gates.len} gates"

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
  unbatched=inputs,
  bitcount=input_bitcount
)

for i in 1..10_000:
  graph.stage_mutation(lookback=lookback)
  let bitpacked_outputs = graph.eval(bitpacked_inputs)
  let outputs = unpack_int64_batches(bitpacked_outputs)

  let output_image = outputs_to_pixie_image(
    outputs,
    height = height,
    width = width,
    channels = channels
    )

  let candidate_error = calculate_mae(branos, output_image)

  if candidate_error < error:
    error = candidate_error
    # output_image.write_file(&"outputs/{i:04}.png")
    output_image.write_file(&"latest.png")
    improved.add(1)
    let improvement_rate = math.sum[int8](improved).float64 /
        improved.len.float64
    echo &"Error: {error:0.3f} at step {i}. Improvement rate: {improvement_rate:0.5f}"
  elif candidate_error == error:
    improved.add(0)
  else:
    improved.add(0)
    graph.undo_mutation()

  if improved.len > improvement_deque_len:
    improved.del(0)


