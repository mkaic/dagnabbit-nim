import ./gate_dag
import pixie as pix
import std/strformat
import progress

var branos = pix.read_image("branos.png")

const
  width = 64
  height = 64
  channels = 3
  layer_size = 1024
  lookback = 2048
  layers = 16


branos = branos.resize(width, height)

let (batches, bitcount) = make_bitpacked_int64_batches(height = height,
    width = width, channels = channels)

echo bitcount
var graph = Graph()

graph.add_inputs(bitcount)
for i in 0 ..< layers:
  graph.init_gates(layer_size, last = lookback)

graph.init_gates(8, output = true, last = lookback)

echo &"Graph has {graph.gates.len} gates"

var error = 255.0

var bar = newProgressBar()
bar.start()
for i in 1..1024:
  var (gate, old_inputs) = graph.stage_mutation(last = 16)

  var outputs: seq[seq[int64]]
  for batch in batches:
    graph.set_inputs(batch)
    outputs.add(graph.evaluate_graph())
    graph.reset()

  let output_image = unpack_int64_outputs_to_pixie(
    outputs,
    height = height,
    width = width,
    channels = channels
    )

  let candidate_error = calculate_mae(branos, output_image)

  if candidate_error < error:
    error = candidate_error
    output_image.write_file(&"outputs/{i:04}.png")
    output_image.write_file(&"latest.png")
  else:
    gate.undo_mutation(old_inputs)

  progress.set(bar, (i.float / 1024.0 * 100.0).int32)
bar.finish()
