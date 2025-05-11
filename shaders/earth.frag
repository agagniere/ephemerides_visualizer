#version 330

in vec2 fragTexCoord;
in vec3 fragNormal;
//in vec3 fragWorldPos;
//in vec3 fragColor;
//in vec3 fragPosition;

uniform sampler2D texture0; // day
uniform sampler2D texture1; // night
uniform sampler2D texture2; // clouds
uniform vec3 sun_dir;       // world-space direction toward the sun
uniform vec4 colDiffuse;

out vec4 finalColor;

void main() {
    vec3 normal = normalize(fragNormal);

    // Compute lighting
    float ndotl = max(dot(normal, sun_dir), 0.0);

    vec4 dayColor = texture(texture0, fragTexCoord);
    vec4 nightColor = texture(texture1, fragTexCoord);
    vec4 cloudColor = texture(texture2, fragTexCoord);

    // Simple cloud blend
    dayColor = mix(dayColor, cloudColor, cloudColor.r);
    // Blend day and night
    vec4 baseColor = mix(nightColor, dayColor, ndotl);

    finalColor = baseColor * colDiffuse;
}
