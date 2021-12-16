package main

import "core:os"
import "core:fmt"
import "core:slice"

ComponentID :: distinct int

Input :: struct {
	component: ComponentID,
	index:     int,
}

Output :: struct {
	state:      bool,
	next_state: bool,
	inputs:     [dynamic]^Input,
}

Component :: struct {
	id:      ComponentID,
	inputs:  []Input,
	outputs: []Output,
	data:    union {
		Switch,
		NotGate,
		OrGate,
		Delayer,
	},
}

Switch :: struct {
	on: bool,
}

MakeSwitch :: proc(new_id: ComponentID, on: bool) -> Component {
	using component: Component
	id = new_id
	inputs = make([]Input, 0)
	outputs = make([]Output, 1)
	outputs[0] = {
		state      = on,
		next_state = on,
		inputs     = make([dynamic]^Input),
	}
	data = Switch {
		on = on,
	}
	return component
}

NotGate :: struct {}

MakeNotGate :: proc(new_id: ComponentID) -> Component {
	using component: Component
	id = new_id
	inputs = make([]Input, 1)
	inputs[0] = {
		component = -1,
		index     = -1,
	}
	outputs = make([]Output, 1)
	outputs[0] = {
		state      = false,
		next_state = false,
		inputs     = make([dynamic]^Input),
	}
	data = NotGate{}
	return component
}

OrGate :: struct {}

MakeOrGate :: proc(new_id: ComponentID) -> Component {
	using component: Component
	id = new_id
	inputs = make([]Input, 2)
	inputs[0] = {
		component = -1,
		index     = -1,
	}
	inputs[1] = {
		component = -1,
		index     = -1,
	}
	outputs = make([]Output, 1)
	outputs[0] = {
		state      = false,
		next_state = false,
		inputs     = make([dynamic]^Input),
	}
	data = OrGate{}
	return component
}

Delayer :: struct {
	previous_inputs: []bool,
}

MakeDelayer :: proc(new_id: ComponentID, delay: int) -> Component {
	using component: Component
	id = new_id
	inputs = make([]Input, 1)
	inputs[0] = {
		component = -1,
		index     = -1,
	}
	outputs = make([]Output, 1)
	outputs[0] = {
		state      = false,
		next_state = false,
		inputs     = make([dynamic]^Input),
	}
	data = Delayer {
		previous_inputs = make([]bool, delay),
	}
	return component
}

DestroyComponent :: proc(id: ComponentID, components: ^map[ComponentID]Component) {
	component := components[id]
	switch c in component.data {
	case Switch:
	case NotGate:
	case OrGate:

	case Delayer:
		delete(c.previous_inputs)

	case:
		unreachable()
	}

	for input in component.inputs {
		input_component := components[input.component]
		output := input_component.outputs[input.index]
		index := -1
		for input_connection, input_index in output.inputs {
			if input_connection.component == id {
				index = input_index
				break
			}
		}
		assert(index != -1)
		ordered_remove(&output.inputs, index)
	}
	delete(component.inputs)

	for output in component.outputs {
		for input in output.inputs {
			input.component = -1
			input.index = -1
		}
		delete(output.inputs)
	}
	delete(component.outputs)

	delete_key(components, id)
}

UpdateComponents :: proc(components: ^map[ComponentID]Component) {
	first_iteration := true
	changed := true
	for changed {
		changed = false

		for _, component in components {
			using component
			switch c in component.data {
			case Switch:
				outputs[0].next_state = c.on
				changed ||= outputs[0].next_state != outputs[0].state

			case NotGate:
                if inputs[0].component < 0 || inputs[0].index < 0 do continue
				input := components[inputs[0].component].outputs[inputs[0].index]
				outputs[0].next_state = !input.state
				changed ||= outputs[0].next_state != outputs[0].state

			case OrGate:
                if inputs[0].component < 0 || inputs[0].index < 0 do continue
				input_0 := components[inputs[0].component].outputs[inputs[0].index]
                if inputs[1].component < 0 || inputs[1].index < 0 do continue
				input_1 := components[inputs[1].component].outputs[inputs[1].index]
				outputs[0].next_state = input_0.state || input_1.state
				changed ||= outputs[0].next_state != outputs[0].state

			case Delayer:
                if inputs[0].component < 0 || inputs[0].index < 0 do continue
                input := components[inputs[0].component].outputs[inputs[0].index]
                assert(len(c.previous_inputs) > 0)
                c.previous_inputs[len(c.previous_inputs)-1] = input.state
                if first_iteration {
                    outputs[0].next_state = c.previous_inputs[0]
                    copy(c.previous_inputs[:len(c.previous_inputs)-1], c.previous_inputs[1:])
                    changed ||= outputs[0].next_state != outputs[0].state
                }

			case:
				unreachable()
			}
		}

		for _, component in components {
			for output in &component.outputs {
				output.state = output.next_state
			}
		}

		first_iteration = false
	}
}

Connect :: proc(
	a: ComponentID,
	out_index: int,
	b: ComponentID,
	in_index: int,
	components: ^map[ComponentID]Component,
) {
	output := &components[a].outputs[out_index]
	input := &components[b].inputs[in_index]
	input.component = a
	input.index = out_index
	append(&output.inputs, input)
}

main :: proc() {
	components: map[ComponentID]Component
	defer {
		for id, _ in components {
			DestroyComponent(id, &components)
		}
		delete(components)
	}

	NextID :: proc() -> ComponentID {
		@(static)
		current_id: ComponentID
		current_id += 1
		return current_id
	}

	switch_a := NextID()
	components[switch_a] = MakeSwitch(switch_a, true)

	not_gate_a := NextID()
	components[not_gate_a] = MakeNotGate(not_gate_a)

	switch_b := NextID()
	components[switch_b] = MakeSwitch(switch_b, true)

	not_gate_b := NextID()
	components[not_gate_b] = MakeNotGate(not_gate_b)

	or_gate := NextID()
	components[or_gate] = MakeOrGate(or_gate)

	not_gate_c := NextID()
	components[not_gate_c] = MakeNotGate(not_gate_c)

    delayer := NextID()
    components[delayer] = MakeDelayer(delayer, 1)

	Connect(switch_a, 0, not_gate_a, 0, &components)
	Connect(switch_b, 0, not_gate_b, 0, &components)

	Connect(not_gate_a, 0, or_gate, 0, &components)
	Connect(not_gate_b, 0, or_gate, 1, &components)

	Connect(or_gate, 0, not_gate_c, 0, &components)

	Connect(not_gate_c, 0, delayer, 0, &components)

	UpdateComponents(&components)

	for id, component in components {
		fmt.printf("%v = %#v\n", id, component)
	}
}
