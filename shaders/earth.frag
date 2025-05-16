#version 330

in vec2 fragTexCoord;
in vec3 fragNormal;
//in vec3 fragWorldPos;
//in vec3 fragColor;
in vec3 fragPosition;

uniform sampler2D texture_day;
uniform sampler2D texture_night;
uniform sampler2D texture_clouds;
uniform sampler2D texture_specular;
uniform vec3 sun_dir; // world-space direction toward the sun, normalized
uniform vec4 colDiffuse;

out vec4 finalColor;

const float edge_size = 0.3;

float light_factor(vec3 normal) {
	float cosine = dot(normal, sun_dir);
	//return clamp(cosine, 0, 1);
	return smoothstep(-0.2, 0.5, cosine);
}

void main() {
    vec3 dayColor    = texture(texture_day, fragTexCoord).rgb;
    vec3 nightColor  = texture(texture_night, fragTexCoord).rgb;
    vec3 cloudColor = texture(texture_clouds, fragTexCoord).rgb;
    dayColor = cloudColor + (1.0 - cloudColor.r) * dayColor;

	float sunlight = light_factor(normalize(fragNormal));
	vec3 earthColor = mix(nightColor, dayColor, sunlight);
    finalColor = vec4(earthColor, 1) * colDiffuse;
}
