package main

import "core:fmt"
import "core:dynlib"
import "core:runtime"
import "core:math/linalg/glsl"

import gl "vendor:OpenGL"

when ODIN_OS == "windows" {

	import "core:sys/win32"

	@(private = "file")
	Renderer :: struct {
		window:             ^Window,
		_opengl_lib:        dynlib.Library,
		_context:           win32.Hglrc,
		_view_matrix:       glsl.mat4,
		_projection_matrix: glsl.mat4,
	}

} else {
	#assert(false, "unsupported platform")
}

@(private = "file")
renderer: Renderer

Renderer_Init :: proc(window: ^Window) -> bool {
	renderer.window = window

	when ODIN_OS == "windows" {

		using win32

		ok: bool
		renderer._opengl_lib, ok = dynlib.load_library("opengl32.dll")
		if !ok {
			fmt.eprintln("Failed to load 'opengl32.dll'")
			return false
		}

		pixel_format := Pixel_Format_Descriptor {
			size         = size_of(Pixel_Format_Descriptor),
			version      = 1,
			flags        = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
			pixel_type   = PFD_TYPE_RGBA,
			color_bits   = 32,
			depth_bits   = 24,
			stencil_bits = 8,
			layer_type   = PFD_MAIN_PLANE,
		}

		format := choose_pixel_format(renderer.window._dc, &pixel_format)
		if format == 0 {
			fmt.eprintln("Failed to choose pixel format")
			return false
		}

		if !set_pixel_format(renderer.window._dc, format, &pixel_format) {
			fmt.eprintln("Failed to set pixel format")
			return false
		}

		temp_context := create_context(renderer.window._dc)
		if temp_context == nil {
			fmt.eprintln("Failed to create temp opengl context")
			return false
		}

		if !make_current(renderer.window._dc, temp_context) {
			fmt.eprintln("Failed to make temp opengl context current")
			return false
		}

		context.user_data = renderer
		get_gl_func :: proc(p: rawptr, name: cstring) {
			using win32

			renderer := &context.user_data.(Renderer)

			when ODIN_OS == "windows" {

				using win32

				ptr := get_gl_proc_address(name)

			} else {
				#assert(false, "unsupported platform")
			}

			if ptr == nil {
				found: bool
				ptr, found = dynlib.symbol_address(renderer._opengl_lib, string(name))
				if !found {
					fmt.eprintf("Failed to load opengl function: '{}'", name)
					return
				}
			}

			(cast(^rawptr)p)^ = ptr
		}

		get_gl_func(&create_context_attribs_arb, "wglCreateContextAttribsARB")

		attribs := []i32{
			CONTEXT_MAJOR_VERSION_ARB,
			4,
			CONTEXT_MINOR_VERSION_ARB,
			4,
			CONTEXT_FLAGS_ARB,
			CONTEXT_CORE_PROFILE_BIT_ARB,
			0,
		}
		renderer._context = create_context_attribs_arb(
			renderer.window._dc,
			nil,
			raw_data(attribs),
		)
		if renderer._context == nil {
			fmt.eprintln("Failed to create opengl context")
			return false
		}

		if !make_current(renderer.window._dc, renderer._context) {
			fmt.eprintln("Failed to make temp opengl context current")
			return false
		}

		delete_context(temp_context)

	} else {
		#assert(false, "unsupported platform")
	}

	gl.load_up_to(4, 4, get_gl_func)

	when ODIN_DEBUG {

		temp := context

		gl.Enable(gl.DEBUG_OUTPUT)
		gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS)
		gl.DebugMessageCallback(
			proc "c" (
				source,
				type,
				id,
				severity: u32,
				length: i32,
				message: cstring,
				userParam: rawptr,
			) {
				context = (cast(^runtime.Context)userParam)^

				switch severity {
				case gl.DEBUG_SEVERITY_HIGH:
					fmt.eprintf("gl.DEBUG_SEVERITY_HIGH: '{}'\n", message)

				case gl.DEBUG_SEVERITY_MEDIUM:
					fmt.eprintf("gl.DEBUG_SEVERITY_MEDIUM: '{}'\n", message)

				case gl.DEBUG_SEVERITY_LOW:
					fmt.eprintf("gl.DEBUG_SEVERITY_LOW: '{}'\n", message)

				case gl.DEBUG_SEVERITY_NOTIFICATION:
					fmt.printf("gl.DEBUG_SEVERITY_NOTIFICATION: '{}'\n", message)

				case:
					fmt.eprintf("gl.DEBUG_SEVERITY_UNKNOWN: '{}'\n", message)
				}
			},
			&temp,
		)

	}

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	return true
}

Renderer_Shutdown :: proc() {
	when ODIN_OS == "windows" {

		using win32

		make_current(renderer.window._dc, nil)
		delete_context(renderer._context)

	} else {
		#assert(false, "unsupported platform")
	}

	dynlib.unload_library(renderer._opengl_lib)
}

Renderer_Present :: proc() {
	when ODIN_OS == "windows" {

		using win32

		swap_buffers(renderer.window._dc)

	} else {
		#assert(false, "unsupported platform")
	}
}

Renderer_OnResize :: proc(width, height: uint) {
	gl.Viewport(0, 0, cast(i32)width, cast(i32)height)
}

Renderer_Clear :: proc(color: glsl.vec4) {
	gl.ClearColor(color.r, color.g, color.b, color.a)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
}

Renderer_Begin :: proc(
	camera_position: glsl.vec3,
	camera_rotation: glsl.quat,
	projection_matrix: glsl.mat4,
	depth_testing: bool,
) {
	if depth_testing {
		gl.Enable(gl.DEPTH_TEST)
	} else {
		gl.Disable(gl.DEPTH_TEST)
	}
	renderer._view_matrix = glsl.inverse_mat4(
		glsl.mat4Translate(camera_position) * glsl.mat4FromQuat(camera_rotation),
	)
	renderer._projection_matrix = projection_matrix
}

Renderer_End :: proc() {
}

Renderer_DrawMesh :: proc(
	mesh: ^Mesh,
	shader: ^Shader,
	model_matrix: Maybe(glsl.mat4) = nil,
	color: Maybe(glsl.vec4) = nil,
) {
	gl.UseProgram(shader._id)
	color_location := gl.GetUniformLocation(shader._id, "u_Color")
	if color_location >= 0 {
		color := color.? or_else glsl.vec4{1.0, 1.0, 1.0, 1.0}
		gl.Uniform4fv(color_location, 1, &color[0])
	}
	model_location := gl.GetUniformLocation(shader._id, "u_Model")
	if model_location >= 0 {
		model := model_matrix.? or_else glsl.identity(glsl.mat4)
		gl.UniformMatrix4fv(model_location, 1, gl.FALSE, &model[0][0])
	}
	view_location := gl.GetUniformLocation(shader._id, "u_View")
	if view_location >= 0 {
		gl.UniformMatrix4fv(view_location, 1, gl.FALSE, &renderer._view_matrix[0][0])
	}
	projection_location := gl.GetUniformLocation(shader._id, "u_Projection")
	if projection_location >= 0 {
		gl.UniformMatrix4fv(
			projection_location,
			1,
			gl.FALSE,
			&renderer._projection_matrix[0][0],
		)
	}
	gl.BindVertexArray(mesh._vertex_array)
	gl.BindBuffer(gl.ARRAY_BUFFER, mesh._vertex_buffer)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh._index_buffer)
	gl.DrawElements(gl.TRIANGLES, cast(i32)mesh._index_count, gl.UNSIGNED_INT, nil)
}
