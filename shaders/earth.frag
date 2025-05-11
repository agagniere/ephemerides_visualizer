#version 330 core

in vec2 fragTexCoord;     // Default Raylib texture coordinate input
out vec4 finalColor;

uniform sampler2D texture0;  // Default texture uniform in Raylib

void main()
{
    finalColor = texture(texture0, fragTexCoord);
}
