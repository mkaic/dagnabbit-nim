import ./gate_dag

var test_graph = Graph()

let input_values = [true, false, false, true, false, false, true, true]

for i in input_values:
  test_graph.add_input(i)

for i in 1..20:
  test_graph.init_gate()

for i in 1..3:
  test_graph.init_gate(output = true)

echo test_graph.evaluate_graph()
test_graph.reset()
