import std/bitops

const
  image_path* = "test_images/branos.png"
  width* = 64
  height* = 64
  num_gates* = 256
  rounds* = 1024
  
const
  output_bitcount* = 8
  channels* = 3
  address_bitcount* = fast_log2(width * height * channels) + 1