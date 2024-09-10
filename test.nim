import ./gate_dag
import pixie as pix
# import std/strformat
import std/bitops
import std/sugar

var test_graph = Graph()

var branos = pix.read_image("branos.png")

const 
  w = 64
  h = 64

let
  x_bitcount = fast_log_2(w) + 1
  y_bitcount = fast_log_2(h) + 1

branos = branos.resize(w, h)
var result_image = pix.new_image(w, h)

var y_as_bits = collect(newSeq):
  for y in 0 ..< h:
    y.int_to_bool_seq(bits=y_bitcount)

var x_as_bits = collect(newSeq):
  for x in 0 ..< w:
    x.int_to_bool_seq(bits=x_bitcount)

var c_as_bits = collect(newSeq):
  for c in 0 ..< 3:
    c.int_to_bool_seq(bits=2)

for i in 1..(x_bitcount + y_bitcount + 3):
  test_graph.add_input()

for i in 1..20:
  test_graph.init_gate()

for i in 1..8:
  test_graph.init_gate(output = true)

      test_graph.set_inputs(pos_bits)
      let output = test_graph.evaluate_graph()
      test_graph.reset()

      rgb[c] = cast[uint8](output.bool_seq_to_int())

    result_image.unsafe[x, y] = pix.rgba(rgb[0], rgb[1], rgb[2], 255)

    let
      rgbx = branos.unsafe[x, y]
      r = rgbx.r # these are uint8
      g = rgbx.g
      b = rgbx.b

result_image.write_file("output_image.png")
