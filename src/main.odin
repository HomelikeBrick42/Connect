package main

import "core:os"
import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:sys/win32"

import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"

Vertex :: struct {
	position: glsl.vec3,
}

Data :: struct {
	running:                  bool,
	window:                   ^Window,
	main_shader:              Shader,
	crosshair_mesh:           Mesh,
	triangle_mesh:            Mesh,
	ui_projection_matrix:     glsl.mat4,
	camera_projection_matrix: glsl.mat4,
	camera_position:          glsl.vec3,
	camera_rotation:          glsl.quat,
	keys:                     [Key]bool,
	mouse_movement:           glsl.vec2,
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

	crosshair_mesh, ok = Mesh_Create(
		[]Vertex{
			{position = {-0.5, +0.5, 0.0}},
			{position = {+0.5, +0.5, 0.0}},
			{position = {+0.5, -0.5, 0.0}},
			{position = {-0.5, -0.5, 0.0}},
		},
		[]u32{0, 1, 2, 0, 2, 3},
		{{type = .Float3, normalized = false}},
	).?
	if !ok {
		fmt.eprintln("Failed to create crosshair mesh")
		os.exit(1)
	}
	defer Mesh_Destroy(&crosshair_mesh)

	triangle_mesh, ok = Mesh_Create(
		[]Vertex{
			{position = {+0.0, +0.5, 0.0}},
			{position = {+0.5, -0.5, 0.0}},
			{position = {-0.5, -0.5, 0.0}},
		},
		[]u32{0, 1, 2},
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
	window.resize_callback = proc(window: ^Window, width, height: uint) {
		using data := window.user_data.(^Data)
		Renderer_OnResize(window.width, window.height)
		camera_projection_matrix = glsl.mat4Perspective(
			60.0 * math.RAD_PER_DEG,
			cast(f32)window.width / cast(f32)window.height,
			0.001,
			1000.0,
		)
		ui_projection_matrix = glsl.mat4Ortho3d(
			-cast(f32)window.width / 2.0,
			+cast(f32)window.width / 2.0,
			-cast(f32)window.height / 2.0,
			+cast(f32)window.height / 2.0,
			-1.0,
			1.0,
		)
	}
	window.key_callback = proc(window: ^Window, key: Key, pressed: bool) {
		using data := window.user_data.(^Data)
		if key == .Unknown do return
		keys[key] = pressed
	}
	window.mouse_move_callback = proc(window: ^Window, x_delta, y_delta: int) {
		using data := window.user_data.(^Data)
		mouse_movement.x += cast(f32)x_delta / cast(f32)window.width * 100.0
		mouse_movement.y += cast(f32)y_delta / cast(f32)window.height * 100.0
	}

	camera_position = {0.0, 0.0, 2.0}
	camera_rotation = glsl.quatAxisAngle({0.0, 1.0, 0.0}, 0.0)

	running = true
	last_time := GetTime()
	Window_Show(window)
	Window_DisableMouse(window)
	mouse_movement = {0.0, 0.0}
	for running {
		Window_Update(window)

		time := GetTime()
		dt := cast(f32)(time - last_time)
		last_time = time

		// Update
		{
			camera_forward := linalg.mul(camera_rotation, glsl.vec3{0.0, 0.0, -1.0})
			camera_right := linalg.mul(camera_rotation, glsl.vec3{-1.0, 0.0, 0.0})
			camera_up := linalg.mul(camera_rotation, glsl.vec3{0.0, 1.0, 0.0})

			camera_rotation = glsl.quatAxisAngle(
	                    camera_up,
	                    -mouse_movement.x * 1000.0 * dt * math.RAD_PER_DEG,
                    ) * camera_rotation
			camera_rotation = glsl.quatAxisAngle(
	                    camera_right,
	                    mouse_movement.y * 1000.0 * dt * math.RAD_PER_DEG,
                    ) * camera_rotation

			rotation_speed: f32 = 90.0
			z_rotation: f32
			if keys[.E] do z_rotation += rotation_speed * dt
			if keys[.Q] do z_rotation -= rotation_speed * dt
			camera_rotation = glsl.quatAxisAngle(camera_forward, z_rotation * math.RAD_PER_DEG) * camera_rotation

			camera_forward = linalg.mul(camera_rotation, glsl.vec3{0.0, 0.0, -1.0})
			camera_right = linalg.mul(camera_rotation, glsl.vec3{-1.0, 0.0, 0.0})
			camera_up = linalg.mul(camera_rotation, glsl.vec3{0.0, 1.0, 0.0})

			camera_speed: f32 = 6.0 if keys[.Shift] else 3.0
			if keys[.W] do camera_position += camera_forward * camera_speed * dt
			if keys[.S] do camera_position -= camera_forward * camera_speed * dt
			if keys[.A] do camera_position += camera_right * camera_speed * dt
			if keys[.D] do camera_position -= camera_right * camera_speed * dt
			if keys[.Space] do camera_position += camera_up * camera_speed * dt
			if keys[.Control] do camera_position -= camera_up * camera_speed * dt
		}

		// Render
		{
			Renderer_Clear({0.2, 0.4, 0.8, 1.0})

			Renderer_Begin(camera_position, camera_rotation, camera_projection_matrix, true)
			Renderer_DrawMesh(
				&triangle_mesh,
				&main_shader,
				glsl.identity(glsl.mat4),
				glsl.vec4{1.0, 0.3, 0.0, 1.0},
			)
			Renderer_End()

			Renderer_Begin({}, {}, ui_projection_matrix, false)
			Renderer_DrawMesh(
				&crosshair_mesh,
				&main_shader,
				glsl.mat4Scale(4.0),
				glsl.vec4{0.0, 0.0, 0.0, 0.6},
			)
			Renderer_End()

			Renderer_Present()
		}

		mouse_movement = {0.0, 0.0}
	}
	Window_EnableMouse(window)
	Window_Hide(window)
}

GetTime :: proc() -> f64 {
	when ODIN_OS == "windows" {
		using win32
		@(static)
		initialized := false
		@(static)
		inverse_frequency := 0.0
		@(static)
		start_time: i64 = 0
		if !initialized {
			query_performance_counter(&start_time)
			frequency: i64
			query_performance_frequency(&frequency)
			inverse_frequency = 1.0 / cast(f64)frequency
			initialized = true
		}
		counter: i64
		query_performance_counter(&counter)
		return cast(f64)counter * inverse_frequency
	} else {
		#assert(false, "unsupported platform")
	}
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
