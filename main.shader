#shader common

#version 440 core

uniform vec4 u_Color = vec4(1.0);
uniform mat4 u_Model = mat4(1.0);
uniform mat4 u_View = mat4(1.0);
uniform mat4 u_Projection = mat4(1.0);

#shader vertex

layout(location = 0) in vec4 a_Position;

void main() {
    gl_Position = u_Projection * u_View * u_Model * a_Position;
}

#shader fragment

layout(location = 0) out vec4 o_Color;

void main() {
    if (u_Color.a < 0.01) {
        discard;
    }
    o_Color = u_Color;
}
