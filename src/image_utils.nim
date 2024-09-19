import pixie as pix
import ./bitty
import std/bitops

proc make_bitpacked_addresses*(
  height: int,
  width: int,
  channels: int,
  ): seq[BitArray] =
  # returs seq(address_bitcount)[BitArray(num_addresses)]
  let address_bitcount = fast_log2(width * height * channels) + 1
  var bitarrays = newSeq[BitArray](address_bitcount)
  for bit_idx in 0 ..< address_bitcount:
    var b = newBitArray(width * height * channels)
    for address in 0 ..< width * height * channels:
      let mask = 1.uint64 shl bit_idx
      b[address] = (address.uint64 and mask) != 0
    bitarrays[bit_idx] = b

  return bitarrays

proc outputs_to_pixie_image*(
  outputs: seq[uint64], # seq(num_addresses)[uint64]
  height: int,
  width: int,
  channels: int,
  ): pix.Image =

  let trimmed = outputs[0 ..< channels * height * width]
  var output_image = pix.new_image(width, height)

  for y in 0 ..< height:
    for x in 0 ..< width:
      var rgb: seq[byte] = newSeq[byte](3)
      for c in 0 ..< 3:
        let idx = (c * height * width) + (y * width) + x
        rgb[c] = trimmed[idx].byte

      output_image.unsafe[x, y] = pix.rgbx(rgb[0], rgb[1], rgb[2], 255)

  return output_image

proc calculate_rmse*(
  image1: pix.Image,
  image2: pix.Image
  ): float32 =

  var error: float32 = 0
  for y in 0 ..< image1.height:
    for x in 0 ..< image1.width:
      let rgb1 = image1.unsafe[x, y]
      let rgb2 = image2.unsafe[x, y]
      error += (rgb1.r.float32 - rgb2.r.float32)^2
      error += (rgb1.g.float32 - rgb2.g.float32)^2
      error += (rgb1.b.float32 - rgb2.b.float32)^2

  error = error.float32 / (image1.width.float32 * image1.height.float32 * 3.0)
  return math.sqrt(error)
