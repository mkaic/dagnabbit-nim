import ./gate_dag
import pixie as pix
# import std/strformat
import std/bitops

var test_graph = Graph()

var branos = pix.read_image("branos.png")
branos = branos.resize(64, 64)
let
  w = branos.width
  h = branos.height
  x_bitcount = fast_log_2(w) + 1
  y_bitcount = fast_log_2(h) + 1

var result_image = pix.new_image(branos.width, branos.height)

for i in 1..(x_bitcount + y_bitcount + 3):
  test_graph.add_input()

for i in 1..20:
  test_graph.init_gate()

for i in 1..8:
  test_graph.init_gate(output = true)


for y in 0 ..< branos.height:
  let y_bits = y.int_to_bool_seq(bits = y_bitcount)

  for x in 0 ..< branos.width:
    let x_bits = x.int_to_bool_seq(bits = x_bitcount)
    var rgb: array[3, uint8]

    for c in 0 ..< 3:
      let c_bits = c.int_to_bool_seq(2)

      let pos_bits = x_bits & y_bits & c_bits

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
