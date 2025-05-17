#version 330

// Inputs from Vertex Shader (Interpolated Per Fragment)
in vec2 fragTexCoord;     /**< Interpolated texture coordinates (u,v) */
in vec3 fragNormal;       /**< Interpolated surface normal in world-space */
in vec3 fragWorldPos;     /**< Interpolated world-space position of the fragment */

// Uniforms
uniform sampler2D texture_day;      /**< Daytime color texture (diffuse map of Earth's surface) */
uniform sampler2D texture_night;    /**< Nighttime texture showing city lights, used when the surface is not lit */
uniform sampler2D texture_clouds;   /**< Cloud texture */
uniform sampler2D texture_specular; /**< Specular map defining specular intensity across Earth's surface (e.g., oceans vs land) */

uniform vec3 sun_dir;     /**< Direction to the sun, in world-space */
uniform vec3 cam_pos;     /**< Camera position in world-space */
uniform vec4 colDiffuse;  /**< Optional base diffuse color multiplier (e.g., for tinting or modulation) */

// Outputs (Final Color Result of the Fragment Shader)
out vec4 finalColor;      /**< Final output color of the fragment */

// Constants
const float specular_power = 32.0; /**< Shininess factor for Blinn-Phong specular lighting (controls highlight sharpness) */

float light_factor(vec3 normal) {
	float cosine = dot(normal, sun_dir);
	return smoothstep(-0.2, 0.7, cosine);
}

float specular_factor(vec3 normal, vec3 view_dir) {
	vec3 half_vector = normalize(sun_dir + view_dir);
	float strength   = texture(texture_specular, fragTexCoord).r;
	float specular   = pow(max(dot(normal, half_vector), 0), specular_power) * strength;
	return specular;
}

void main() {
	vec3 dayColor	 = texture(texture_day, fragTexCoord).rgb;
	vec3 nightColor	 = texture(texture_night, fragTexCoord).rgb;
	float cloudColor = texture(texture_clouds, fragTexCoord).r;

	vec3 normal      = normalize(fragNormal);
	float specular   = specular_factor(normal, normalize(cam_pos - fragWorldPos));
	float sunlight	 = light_factor(normal);

	dayColor        += specular;
	cloudColor		 = smoothstep(0, 0.85, cloudColor);
	dayColor		 = mix(dayColor, vec3(1), cloudColor);
	nightColor	     = mix(nightColor, nightColor / 8, cloudColor);

	vec3 earthColor	 = mix(nightColor, dayColor, sunlight);

	finalColor		 = vec4(earthColor, 1) * colDiffuse;
}
