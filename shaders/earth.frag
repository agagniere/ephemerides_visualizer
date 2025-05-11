#version 330 core

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform sampler2D texture1;
uniform sampler2D texture2;

uniform vec3 sun_dir;
uniform vec4 colDiffuse;

void main()
{
    // Approximate surface normal from UV for sphere
    vec2 uv = fragTexCoord;
    vec2 centered = uv * 2.0 - 1.0;
    float z = sqrt(1.0 - clamp(dot(centered, centered), 0.0, 1.0));
    vec3 normal = normalize(vec3(centered, z));

    // Light intensity from sun direction
    float light = clamp(dot(normal, normalize(sun_dir)), 0.0, 1.0);

    // Get base color from day and night textures
    vec3 dayColor = texture(texture0, uv).rgb;
    vec3 nightColor = texture(texture1, uv).rgb;

    // Blend day/night based on light
    vec3 baseColor = mix(nightColor, dayColor, light);

    // Sample clouds and blend
    float cloudAlpha = texture(texture2, uv).r; // grayscale
    vec3 cloudColor = vec3(1.0); // white clouds
    vec3 finalRgb = mix(baseColor, cloudColor, cloudAlpha * 0.5); // semi-transparent clouds

    finalColor = vec4(finalRgb, 1.0) * colDiffuse;
}
