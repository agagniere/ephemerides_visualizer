#version 330

// Vertex Attributes (Inputs to the Vertex Shader)
in vec3 vertexPosition; /**< Model-space coordinates of the vertex */
in vec2 vertexTexCoord; /**< Texture coordinates (u,v), in range [0,1] */
in vec3 vertexNormal;   /**< Normal vector at the vertex, in model-space */

// Uniforms (Global shader inputs set by the CPU)
uniform mat4 mvp;       /**< Combined Model-View-Projection matrix: transforms from model-space to clip-space (screen-space) */
uniform mat4 matModel;  /**< Model matrix: transforms coordinates from model-space to world-space */
uniform mat4 matNormal; /**< Normal matrix: typically the inverse transpose of the upper-left 3x3 of matModel; used to correctly transform normals to world-space */

// Varyings (Outputs from the Vertex Shader to be interpolated and passed to the Fragment Shader)
out vec2 fragTexCoord;  /**< Texture coordinates passed to the fragment shader (interpolated across the triangle) */
out vec3 fragNormal;    /**< Normal vector in world-space, for use in lighting calculations in the fragment shader */
out vec3 fragWorldPos;  /**< Position of the vertex in world-space, used for lighting and view direction */

void main() {
	fragTexCoord = vertexTexCoord;

	vec4 worldPos = matModel * vec4(vertexPosition, 1.0);
	fragWorldPos = worldPos.xyz;

	fragNormal = normalize((matNormal * vec4(vertexNormal, 0.0)).xyz);

	gl_Position = mvp * vec4(vertexPosition, 1.0);
}
