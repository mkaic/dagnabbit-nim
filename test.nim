import ./gate_dag
import pixie as pix
# import std/strformat
import std/sugar

var branos = pix.read_image("branos.png")

const 
  width = 128
  height = 128
  channels = 3

branos = branos.resize(width, height)

let (batches, bitcount) = make_bitpacked_int64_batches(height=height, width=width, channels=channels)

echo bitcount
var graph = Graph()
graph.init_as_reconstructor(input_size=bitcount, output_size=8, num_gates=1024)

var outputs: seq[seq[int64]]
for batch in batches:
  graph.set_inputs(batch)
  outputs.add(graph.evaluate_graph())
  graph.reset()

let output_image = unpack_int64_outputs_to_pixie(outputs, height=height, width=width, channels=channels)

output_image.write_file("output_image.png")

#       rgb[c] = cast[uint8](output.bool_seq_to_int())

#     result_image.unsafe[x, y] = pix.rgba(rgb[0], rgb[1], rgb[2], 255)

#     let
#       rgbx = branos.unsafe[x, y]
#       r = rgbx.r # these are uint8
#       g = rgbx.g
#       b = rgbx.b

# result_image.write_file("output_image.png")
