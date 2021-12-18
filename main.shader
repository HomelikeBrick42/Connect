#shader common

#version 440 core

uniform vec4 u_Color = vec4(1.0);
uniform mat4 u_Model = mat4(1.0);
uniform mat4 u_View = mat4(1.0);
uniform mat4 u_Projection = mat4(1.0);

#shader vertex

layout(location = 0) in vec4 a_Position;
layout(location = 1) in vec3 a_Normal;

layout(location = 0) out vec3 v_Normal;

void main() {
    v_Normal = (u_Model * vec4(a_Normal, 0.0)).xyz;
    gl_Position = u_Projection * u_View * u_Model * a_Position;
}

#shader fragment

layout(location = 0) out vec4 o_Color;

layout(location = 0) in vec3 v_Normal;

void main() {
    if (u_Color.a < 0.01) {
        discard;
    }
    o_Color = u_Color;
    o_Color.rgb *= dot(v_Normal, -normalize(vec3(-0.3, -0.4, -0.2))) + 1.0;
}
