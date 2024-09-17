# Spock
I'm learning [Nim](nim-lang.org) and experimenting with evolutionary algorithms to generate logical functions.

As a test-case, I'm attempting to map from the binary address of an image byte (represented as 3 n-bit integers corresponding to the X, Y, and C coordinates of the byte) to the byte value itself. This is done by a randomly-initialized [DAG](https://en.wikipedia.org/wiki/Directed_acyclic_graph) of basic logic gates selected from `{AND, NAND, OR, NOR, XOR, XNOR}`.

Right now, the DAG is optimized by trial-and-error through random mutations which alter either the type or the inputs of a random gate each iteration. However, I'd like to implement a smarter search/evolution procedure soon.

### Dependencies:
* [Pixie](https://github.com/treeform/pixie) for image loading and saving.
* [Bitty](https://github.com/treeform/bitty) (vendored in as `src/bitty` and lightly modified) for arbitrary-length bitvector data structure.