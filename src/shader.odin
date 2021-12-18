package main

import "core:fmt"
import "core:os"
import "core:strings"

import gl "vendor:OpenGL"

Shader :: struct {
	_id: u32,
}

Shader_Create :: proc(filepath: string) -> Maybe(Shader) {
	bytes, ok := os.read_entire_file(filepath)
	if !ok do return nil
	defer delete(bytes)
	file := string(bytes)

	vertex_source_builder := strings.make_builder()
	defer strings.destroy_builder(&vertex_source_builder)

	fragment_source_builder := strings.make_builder()
	defer strings.destroy_builder(&fragment_source_builder)

	sections := strings.split(file, "#shader")
	defer delete(sections)
	for section in sections {
		section := strings.trim(section, " \t\n\r")
		if len(section) == 0 do continue
		switch {
		case strings.has_prefix(section, "common"):
			section := section[len("common"):]
			strings.write_string_builder(&vertex_source_builder, section)
			strings.write_string_builder(&fragment_source_builder, section)
		case strings.has_prefix(section, "vertex"):
			section := section[len("vertex"):]
			strings.write_string_builder(&vertex_source_builder, section)
		case strings.has_prefix(section, "fragment"):
			section := section[len("fragment"):]
			strings.write_string_builder(&fragment_source_builder, section)
		case:
			fmt.eprintln("Unknown shader section")
			return nil
		}
	}

	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	vertex_source := cstring(raw_data(strings.to_string(vertex_source_builder)))
	vertex_source_length := cast(i32)len(vertex_source)
	gl.ShaderSource(vertex_shader, 1, &vertex_source, &vertex_source_length)
	gl.CompileShader(vertex_shader)

	vertex_shader_compiled: i32
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &vertex_shader_compiled)
	if vertex_shader_compiled == 0 {
		gl.DeleteShader(vertex_shader)
		fmt.eprintln("Failed to compile vertex shader")
		return nil
	}

	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	fragment_source := cstring(raw_data(strings.to_string(fragment_source_builder)))
	fragment_source_length := cast(i32)len(fragment_source)
	gl.ShaderSource(fragment_shader, 1, &fragment_source, &fragment_source_length)
	gl.CompileShader(fragment_shader)

	fragment_shader_compiled: i32
	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &fragment_shader_compiled)
	if fragment_shader_compiled == 0 {
		gl.DeleteShader(vertex_shader)
		gl.DeleteShader(fragment_shader)
		fmt.eprintln("Failed to compile fragment shader")
		return nil
	}

	program := gl.CreateProgram()
	gl.AttachShader(program, vertex_shader)
	gl.AttachShader(program, fragment_shader)
	gl.LinkProgram(program)

	program_linked: i32
	gl.GetProgramiv(program, gl.LINK_STATUS, &program_linked)
	if program_linked == 0 {
		gl.DeleteShader(vertex_shader)
		gl.DeleteShader(fragment_shader)
		gl.DeleteProgram(program)
		fmt.eprintln("Failed to link shader")
		return nil
	}

	gl.DetachShader(program, vertex_shader)
	gl.DetachShader(program, fragment_shader)
	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)

	return Shader{_id = program}
}

Shader_Destroy :: proc(shader: ^Shader) {
	gl.DeleteProgram(shader._id)
}
