package main

import "core:os"
import "core:fmt"

ComponentID :: distinct uint
Connection :: distinct [dynamic]ComponentID

Component :: struct {
    name:       string,
    id:         ComponentID,
    state:      bool,
    next_state: bool,
    inputs:     []Connection,
    has_delay:  bool,
    update:     proc(^Component, []Component) -> bool,
}

MakeSwitch :: proc(id: ComponentID) -> Component do return Component{
    name       = "Switch",
    id         = id,
    state      = false,
    next_state = false,
    inputs     = make([]Connection, 0),
    has_delay  = false,
    update     = proc(using component: ^Component, components: []Component) -> bool {
        assert(len(inputs) == 0)
        return false
    },
}

MakeNotGate :: proc(id: ComponentID) -> Component do return Component{
    name       = "Not",
    id         = id,
    state      = false,
    next_state = false,
    inputs     = make([]Connection, 1),
    has_delay  = false,
    update     = proc(using component: ^Component, components: []Component) -> bool {
        assert(len(inputs) == 1)

        input_0 := false
        for input in inputs[0] {
            input_0 ||= components[input].state
        }

        next_state = !input_0
        return next_state != state
    },
}

MakeAndGate :: proc(id: ComponentID) -> Component do return Component{
    name       = "And",
    id         = id,
    state      = false,
    next_state = false,
    inputs     = make([]Connection, 2),
    has_delay  = false,
    update     = proc(using component: ^Component, components: []Component) -> bool {
        assert(len(inputs) == 2)

        input_0 := false
        for input in inputs[0] {
            input_0 ||= components[input].state
        }

        input_1 := false
        for input in inputs[1] {
            input_1 ||= components[input].state
        }

        next_state = input_0 && input_1
        return next_state != state
    },
}

HasCyclicConnections :: proc(components: []Component) -> bool {
    searched_components := make(map[ComponentID]bool, len(components))
    defer delete(searched_components)

    for component in components {
        if searched_components[component.id] {
            continue
        }

        seen_components := make(map[ComponentID]bool, len(components))
        defer delete(seen_components)

        stack := make([dynamic]ComponentID)
        defer delete(stack)

        append(&stack, component.id)

        for len(stack) > 0 {
            current := pop(&stack)

            if seen_components[current] {
                return true
            }
            seen_components[current] = true

            if components[current].has_delay {
                continue
            }

            for input_list in components[current].inputs {
                for input in input_list {
                    append(&stack, input)
                    searched_components[input] = true
                }
            }
        }
    }

    return false
}

main :: proc() {
    components: [dynamic]Component
    defer {
        for component in components {
            for input_list in component.inputs {
                delete(input_list)
            }
            delete(component.inputs)
        }
        delete(components)
    }

    AddComponent :: proc(components: ^[dynamic]Component, make_component_func: proc(id: ComponentID) -> Component) -> ComponentID {
        id := cast(ComponentID) len(components^)
        append(components, make_component_func(id))
        return id
    }

    AddConnection :: proc(components: []Component, from_id: ComponentID, to_id: ComponentID, input_index: ComponentID) {
        append(&components[to_id].inputs[input_index], from_id)
    }

    SetState :: proc(components: []Component, component: ComponentID, state: bool) {
        components[component].next_state = state
    }

    switch_a := AddComponent(&components, MakeSwitch)
    SetState(components[:], switch_a, true)

    switch_b := AddComponent(&components, MakeSwitch)
    SetState(components[:], switch_b, true)

    and_gate := AddComponent(&components, MakeAndGate)
    AddConnection(components[:], switch_a, and_gate, 0)
    AddConnection(components[:], switch_b, and_gate, 1)

    not_gate := AddComponent(&components, MakeNotGate)
    AddConnection(components[:], and_gate, not_gate, 0)

    assert(!HasCyclicConnections(components[:]), "the circuit cannot have cyclic connections")

    changes := true
    for changes {
        changes = false

        for component in &components {
            if component.update(&component, components[:]) {
                changes = true
            }
        }

        for component in &components {
            component.state = component.next_state
        }
    }
}
