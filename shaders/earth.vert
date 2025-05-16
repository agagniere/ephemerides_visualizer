#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
//in vec3 vertexColor;
in vec3 vertexNormal;

uniform mat4 mvp;
uniform mat4 matModel;
uniform mat4 matNormal;

out vec2 fragTexCoord;
out vec3 fragNormal;
//out vec3 fragColor;
out vec3 fragPosition;
//out vec3 fragWorldPos;

void main() {
    fragTexCoord = vertexTexCoord;
	//fragColor = vertexColor;
	fragPosition = vertexPosition;

    //vec4 worldPos = matModel * vec4(vertexPosition, 1.0);
    //fragWorldPos = worldPos.xyz;

    // Correct normal transformed to world space
    fragNormal = normalize((matNormal * vec4(vertexNormal, 0.0)).xyz);

    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
