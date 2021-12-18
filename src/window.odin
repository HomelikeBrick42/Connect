package main

import "core:fmt"
import "core:runtime"

Key :: enum {
	Unknown,
	W,
	A,
	S,
	D,
	Q,
	E,
}

when ODIN_OS == "windows" {

	import "core:sys/win32"

	Window :: struct {
		width, height:   uint,
		user_data:       any,
		close_callback:  proc(window: ^Window),
		resize_callback: proc(window: ^Window),
		key_callback:    proc(window: ^Window, key: Key, pressed: bool),
		_instance:       win32.Hinstance,
		_handle:         win32.Hwnd,
		_dc:             win32.Hdc,
		_context:        runtime.Context,
	}

	@(private = "file")
	WindowClassName :: "WindowClass"

	@(private = "file")
	window_class_initialized := false

	// TODO: Create a pull request for `core:sys/win32`
	WM_NCCREATE: u32 : 0x0081
	CREATESTRUCTA :: struct {
		lpCreateParams: rawptr,
		hInstance:      win32.Hinstance,
		hMenu:          win32.Hmenu,
		hwndParent:     win32.Hwnd,
		cy:             i32,
		cx:             i32,
		y:              i32,
		x:              i32,
		style:          i32,
		lpszName:       cstring,
		lpszClass:      cstring,
		dwExStyle:      i32,
	}

	SW_HIDE: i32 : 0

	@(private = "file")
	WindowProc :: proc "std" (
		hwnd: win32.Hwnd,
		message: u32,
		w_param: win32.Wparam,
		l_param: win32.Lparam,
	) -> win32.Lresult {
		using win32

		result: Lresult = 0

		if message == WM_NCCREATE {
			create_struct := transmute(^CREATESTRUCTA)l_param
			window := cast(^Window)create_struct.lpCreateParams
			set_window_long_ptr_a(hwnd, GWLP_USERDATA, transmute(Long_Ptr)window)
			return def_window_proc_a(hwnd, message, w_param, l_param)
		}

		window := transmute(^Window)get_window_long_ptr_a(hwnd, GWLP_USERDATA)
		if window == nil {
			return def_window_proc_a(hwnd, message, w_param, l_param)
		}

		context = window._context

		switch message {
		case WM_CLOSE, WM_DESTROY, WM_QUIT:
			if window.close_callback != nil {
				window.close_callback(window)
			}

		case WM_SIZE:
			if window.resize_callback != nil {
				rect: Rect
				get_client_rect(hwnd, &rect)
				width := rect.right - rect.left
				height := rect.bottom - rect.top
				if width > 0 && height > 0 {
					window.width = cast(uint)width
					window.height = cast(uint)height
					window.resize_callback(window)
				}
			}

		case WM_KEYDOWN, WM_SYSKEYDOWN, WM_KEYUP, WM_SYSKEYUP:
			if window.key_callback != nil {
				pressed := message == WM_KEYDOWN || message == WM_SYSKEYDOWN
				key: Key
				switch w_param {
				case 'W':
					key = .W
				case 'A':
					key = .A
				case 'S':
					key = .S
				case 'D':
					key = .D
				case 'Q':
					key = .Q
				case 'E':
					key = .E
				case:
					key = .Unknown
				}
				for _ in 0 ..< l_param & 0xF {
					window.key_callback(window, key, pressed)
				}
			}

		case:
			result = def_window_proc_a(hwnd, message, w_param, l_param)
		}

		return result
	}

	Window_Create :: proc(width, height: uint, title: cstring) -> Maybe(^Window) {
		using win32
		window := new(Window)

		window._instance = auto_cast get_module_handle_a(nil)
		if window._instance == nil {
			fmt.eprintf("Failed to get the current module handle {}\n", get_last_error())
			free(window)
			return nil
		}

		if !window_class_initialized {
			window_class := Wnd_Class_Ex_A {
				size       = size_of(Wnd_Class_Ex_A),
				style      = CS_OWNDC,
				wnd_proc   = WindowProc,
				instance   = window._instance,
				cursor     = load_cursor_a(nil, IDC_ARROW),
				class_name = WindowClassName,
			}
			if register_class_ex_a(&window_class) == 0 {
				fmt.eprintf("Failed to regiser window class {}\n", get_last_error())
				free(window)
				return nil
			}
			window_class_initialized = true
		}

		rect: Rect
		rect.left = 100
		rect.right = rect.left + cast(i32)width
		rect.top = 100
		rect.bottom = rect.top + cast(i32)height
		adjust_window_rect(&rect, WS_OVERLAPPEDWINDOW, false)

		window.width = cast(uint)(rect.right - rect.left)
		window.height = cast(uint)(rect.bottom - rect.top)

		window._handle = create_window_ex_a(
			0,
			WindowClassName,
			title,
			WS_OVERLAPPEDWINDOW,
			CW_USEDEFAULT,
			CW_USEDEFAULT,
			cast(i32)window.width,
			cast(i32)window.height,
			nil,
			nil,
			window._instance,
			window,
		)
		if window._handle == nil {
			fmt.eprintf("Failed to create window {}\n", get_last_error())
			free(window)
			return nil
		}

		window._dc = get_dc(window._handle)
		if window._dc == nil {
			fmt.eprintf("Failed to get the device context {}\n", get_last_error())
			destroy_window(window._handle)
			free(window)
			return nil
		}

		return window
	}

	Window_Destroy :: proc(window: ^Window) {
		using win32
		release_dc(window._handle, window._dc)
		destroy_window(window._handle)
		free(window)
	}

	Window_Update :: proc(window: ^Window) {
		using win32
		window._context = context
		message: Msg
		for peek_message_a(&message, window._handle, 0, 0, PM_REMOVE) {
			translate_message(&message)
			dispatch_message_a(&message)
		}
	}

	Window_Show :: proc(window: ^Window) {
		using win32
		show_window(window._handle, SW_SHOW)
	}

	Window_Hide :: proc(window: ^Window) {
		using win32
		show_window(window._handle, SW_HIDE)
	}

} else {
	#assert(false, "unsupported platform")
}
