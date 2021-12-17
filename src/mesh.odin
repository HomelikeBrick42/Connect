package main

import gl "vendor:OpenGL"

VertexLayoutElementType :: enum {
	Float,
	Float2,
	Float3,
	Float4,
}

@(private = "file")
type_size := [VertexLayoutElementType]uint {
	.Float  = size_of(f32) * 1,
	.Float2 = size_of(f32) * 2,
	.Float3 = size_of(f32) * 3,
	.Float4 = size_of(f32) * 4,
}

@(private = "file")
type_count := [VertexLayoutElementType]uint {
	.Float  = 1,
	.Float2 = 2,
	.Float3 = 3,
	.Float4 = 4,
}

gl_type := [VertexLayoutElementType]uint {
	.Float  = gl.FLOAT,
	.Float2 = gl.FLOAT,
	.Float3 = gl.FLOAT,
	.Float4 = gl.FLOAT,
}

VertexLayoutElement :: struct {
	type:       VertexLayoutElementType,
	normalized: bool,
}

Mesh :: struct {
	_vertex_array:  u32,
	_vertex_buffer: u32,
	_index_buffer:  u32,
}

Mesh_Create :: proc(
	vertices: []$T,
	indices: []u32,
	layout: []VertexLayoutElement,
) -> Maybe(Mesh) {
	mesh: Mesh
	gl.GenVertexArrays(1, &mesh._vertex_array)
	gl.GenBuffers(1, &mesh._vertex_buffer)
	Mesh_SetVertices(&mesh, vertices)
	gl.GenBuffers(1, &mesh._index_buffer)
	Mesh_SetIndices(&mesh, indices)
	Mesh_SetLayout(&mesh, layout)
	return mesh
}

Mesh_Destroy :: proc(mesh: ^Mesh) {
	gl.DeleteBuffers(1, &mesh._index_buffer)
	gl.DeleteBuffers(1, &mesh._vertex_buffer)
	gl.DeleteVertexArrays(1, &mesh._vertex_array)
}

Mesh_SetVertices :: proc(mesh: ^Mesh, vertices: []$T) {
	gl.BindVertexArray(mesh._vertex_array)
	gl.BindBuffer(gl.ARRAY_BUFFER, mesh._vertex_buffer)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(T),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)
}

Mesh_SetIndices :: proc(mesh: ^Mesh, indices: []u32) {
	gl.BindVertexArray(mesh._vertex_array)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh._index_buffer)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(indices) * size_of(u32),
		raw_data(indices),
		gl.STATIC_DRAW,
	)
}

Mesh_SetLayout :: proc(mesh: ^Mesh, layout: []VertexLayoutElement) {
	gl.BindVertexArray(mesh._vertex_array)
	gl.BindBuffer(gl.ARRAY_BUFFER, mesh._vertex_buffer)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, mesh._index_buffer)
	stride: i32 = 0
	for element in layout do stride += cast(i32)type_size[element.type]
	offset: uintptr = 0
	for element, i in layout {
		gl.EnableVertexAttribArray(cast(u32)i)
		gl.VertexAttribPointer(
			cast(u32)i,
			cast(i32)type_count[element.type],
			cast(u32)gl_type[element.type],
			element.normalized,
			stride,
			offset,
		)
		offset += cast(uintptr)type_size[element.type]
	}
}
