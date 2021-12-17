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
		window:      ^Window,
		_opengl_lib: dynlib.Library,
		_context:    win32.Hglrc,
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
			return false
		}

		if !set_pixel_format(renderer.window._dc, format, &pixel_format) {
			return false
		}

		renderer._context = create_context(renderer.window._dc)
		if renderer._context == nil {
			return false
		}

		if !make_current(renderer.window._dc, renderer._context) {
			return false
		}

	} else {
		#assert(false, "unsupported platform")
	}

	context.user_data = renderer
	gl.load_up_to(4, 4, proc(p: rawptr, name: cstring) {
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
					return
				}
			}

			(cast(^rawptr)p)^ = ptr
		})

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
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)
}
