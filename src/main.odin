package main

import "core:os"
import "core:fmt"
import "core:reflect"
import "core:strings"

import "core:math"
import "core:math/linalg/glsl"

Vertex :: struct {
	position: glsl.vec3,
}

Data :: struct {
	running:       bool,
	window:        ^Window,
	main_shader:   Shader,
	triangle_mesh: Mesh,
}

main2 :: proc() {
	bytes, _ := os.read_entire_file("main.shader")
	source := string(bytes)
	sections := strings.split(source, "#shader")
	for section in sections {
		section := strings.trim(section, " \n\r\t")
		if len(section) == 0 do continue

		type := "vertex"
		if strings.has_prefix(section, type) {
			fmt.println("found")
			fmt.println("----------------------------")
			fmt.println(section[len(type):])
			fmt.println("----------------------------")
		} else {
			fmt.println("not found")
		}
	}
}

main :: proc() {
	// ComponentTest()

	using data := new(Data)
	defer free(data)

	ok: bool
	window, ok = Window_Create(640, 480, "Hello").?
	if !ok {
		fmt.eprintln("Failed to create window")
		os.exit(1)
	}
	defer Window_Destroy(window)

	ok = Renderer_Init(window)
	if !ok {
		fmt.eprintln("Failed to create renderer")
		os.exit(1)
	}
	defer Renderer_Shutdown()

	main_shader, ok = Shader_Create("main.shader").?
	if !ok {
		fmt.eprintln("Failed to create main shader")
		os.exit(1)
	}
	defer Shader_Destroy(&main_shader)

	triangle_vertices := [?]Vertex{
		{position = {+0.0, +0.5, 0.0}},
		{position = {+0.5, -0.5, 0.0}},
		{position = {-0.5, -0.5, 0.0}},
	}

	triangle_indices := [?]u32{0, 1, 2}

	triangle_mesh, ok = Mesh_Create(
		triangle_vertices[:],
		triangle_indices[:],
		{{type = .Float3, normalized = false}},
	).?
	if !ok {
		fmt.eprintln("Failed to create triangle mesh")
		os.exit(1)
	}
	defer Mesh_Destroy(&triangle_mesh)

	window.user_data = data
	window.close_callback = proc(window: ^Window) {
		using data := window.user_data.(^Data)
		running = false
	}
	window.resize_callback = proc(window: ^Window) {
		using data := window.user_data.(^Data)
		Renderer_OnResize(window.width, window.height)
	}

	running = true
	Window_Show(window)
	for running {
		Window_Update(window)

		Renderer_Clear({0.1, 0.1, 0.1, 1.0})
		Renderer_DrawMesh(&triangle_mesh, &main_shader, glsl.vec4{1.0, 0.0, 0.0, 1.0})
		Renderer_Present()
	}
	Window_Hide(window)
}

ComponentTest :: proc() {
	components: map[ComponentID]Component
	defer {
		for id, _ in components {
			DestroyComponent(id, &components)
		}
		delete(components)
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

	if HasCyclicDependency(&components) {
		fmt.eprintln("circuit has a cyclic dependency")
		os.exit(1)
	}

	UpdateComponents(&components)

	for id, component in components {
		fmt.printf("{}: ", reflect.union_variant_typeid(component.data))
		for output, i in component.outputs {
			if i > 0 {
				fmt.print(", ")
			}
			fmt.print(output.state)
		}
		fmt.println()
	}
}
