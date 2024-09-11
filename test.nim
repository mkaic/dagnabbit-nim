import ./gate_dag
import pixie as pix
# import std/strformat
import std/sugar

var branos = pix.read_image("branos.png")

const
  width = 64
  height = 64
  channels = 3

branos = branos.resize(width, height)

let (batches, bitcount) = make_bitpacked_int64_batches(height = height,
    width = width, channels = channels)

echo bitcount
var graph = Graph()

graph.add_inputs(bitcount)
for i in 0 ..< 64:
  graph.init_gates(64, last = 64)

graph.init_gates(8, output = true, last = 64)


var outputs: seq[seq[int64]]
for batch in batches:
  graph.set_inputs(batch)
  outputs.add(graph.evaluate_graph())
  graph.reset()

var output_image = unpack_int64_outputs_to_pixie(outputs, height = height,
    width = width, channels = channels)

output_image = output_image.resize(1024, 1024)
output_image.write_file("output_image.png")

#       rgb[c] = cast[uint8](output.bool_seq_to_int())

#     result_image.unsafe[x, y] = pix.rgba(rgb[0], rgb[1], rgb[2], 255)

#     let
#       rgbx = branos.unsafe[x, y]
#       r = rgbx.r # these are uint8
#       g = rgbx.g
#       b = rgbx.b

# result_image.write_file("output_image.png")
