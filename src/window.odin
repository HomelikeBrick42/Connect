package main

import "core:fmt"
import "core:runtime"

Key :: enum {
	Unknown,
	W,
	S,
	A,
	D,
	Q,
	E,
	Shift,
	Space,
	Control,
}

when ODIN_OS == "windows" {

	import "core:sys/win32"

	Window :: struct {
		width, height:       uint,
		mouse_disabled:      bool,
		user_data:           any,
		close_callback:      proc(window: ^Window),
		resize_callback:     proc(window: ^Window, width, height: uint),
		key_callback:        proc(window: ^Window, key: Key, pressed: bool),
		mouse_move_callback: proc(window: ^Window, x_delta, y_delta: int),
		_instance:           win32.Hinstance,
		_handle:             win32.Hwnd,
		_dc:                 win32.Hdc,
		_context:            runtime.Context,
	}

	@(private = "file")
	WindowClassName :: "WindowClass"

	@(private = "file")
	window_class_initialized := false

	foreign import "system:user32.lib"
	@(default_calling_convention = "std")
	foreign user32 {
		ShowCursor :: proc(bShow: win32.Bool) -> i32 ---
		ClipCursor :: proc(lpRect: ^win32.Rect) -> win32.Bool ---
		MapWindowPoints :: proc(
			hWndFrom: win32.Hwnd,
			hWndTo: win32.Hwnd,
			lpPoints: ^win32.Point,
			cPoints: u32,
		) -> i32 ---
	}

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
					window.resize_callback(window, window.width, window.height)
				}
			}

		case WM_KEYDOWN, WM_SYSKEYDOWN, WM_KEYUP, WM_SYSKEYUP:
			if window.key_callback != nil {
				pressed := message == WM_KEYDOWN || message == WM_SYSKEYDOWN
				key: Key
				switch w_param {
				case 'W':
					key = .W
				case 'S':
					key = .S
				case 'A':
					key = .A
				case 'D':
					key = .D
				case 'Q':
					key = .Q
				case 'E':
					key = .E
				case VK_SHIFT:
					key = .Shift
				case VK_SPACE:
					key = .Space
				case VK_CONTROL:
					key = .Control
				case:
					key = .Unknown
				}
				for _ in 0 ..< l_param & 0xF {
					window.key_callback(window, key, pressed)
				}
			}
			result = def_window_proc_a(hwnd, message, w_param, l_param)

		case WM_INPUT:
			if window.mouse_move_callback != nil {
				raw_input := transmute(Hrawinput)l_param
				size: u32
				if get_raw_input_data(raw_input, RID_INPUT, nil, &size, size_of(Raw_Input_Header)) ==
				   max(u32) {
					fmt.printf("Failed to get the size of the mouse input data {}\n", get_last_error())
				}
				bytes := make([]byte, cast(int)size)
				defer delete(bytes)
				if get_raw_input_data(
					   raw_input,
					   RID_INPUT,
					   raw_data(bytes),
					   &size,
					   size_of(Raw_Input_Header),
				   ) == max(u32) {
					fmt.printf("Failed to get the mouse input data {}\n", get_last_error())
				}
				input := cast(^Raw_Input)raw_data(bytes)
				mouse_x := input.data.mouse.last_x
				mouse_y := input.data.mouse.last_y
				window.mouse_move_callback(window, cast(int)mouse_x, cast(int)mouse_y)
			}

		case WM_KILLFOCUS:
			if window.mouse_disabled {
				for ShowCursor(true) < 0 {}
				ClipCursor(nil)
			}

		case WM_SETFOCUS:
			if window.mouse_disabled {
				for ShowCursor(false) >= 0 {}
				rect: Rect
				get_client_rect(window._handle, &rect)
				MapWindowPoints(
					window._handle,
					nil,
					cast(^Point)&rect,
					size_of(Rect) / size_of(Point),
				)
				ClipCursor(&rect)
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

		raw_input := Raw_Input_Device {
			usage_page = 0x01,
			usage      = 0x02,
		}
		if !register_raw_input_devices(&raw_input, 1, size_of(Raw_Input_Device)) {
			fmt.eprintf("Failed to enable raw input {}\n", get_last_error())
			release_dc(window._handle, window._dc)
			destroy_window(window._handle)
			free(window)
			return nil
		}

		return window
	}

	Window_Destroy :: proc(window: ^Window) {
		using win32
		if window.mouse_disabled {
			Window_EnableMouse(window)
		}
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

	Window_EnableMouse :: proc(window: ^Window) {
		for ShowCursor(true) < 0 {}
		ClipCursor(nil)
		window.mouse_disabled = false
	}

	Window_DisableMouse :: proc(window: ^Window) {
		using win32
		for ShowCursor(false) >= 0 {}
		rect: Rect
		get_client_rect(window._handle, &rect)
		MapWindowPoints(window._handle, nil, cast(^Point)&rect, size_of(Rect) / size_of(Point))
		ClipCursor(&rect)
		window.mouse_disabled = true
	}

} else {
	#assert(false, "unsupported platform")
}
