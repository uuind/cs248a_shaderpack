#version 330 compatibility

uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;

flat out float blockID;
in vec4 mc_Entity;

void main() {
    blockID = mc_Entity.x;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
    normal = mat3(gbufferModelViewInverse) * gl_Normal;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;

    if(abs(blockID - 3.0) < 1.0) { // grass

        vec4 worldPos = gbufferModelViewInverse * viewPos;
        float heightFactor = smoothstep(0.1, 1.0, 1.0 - texcoord.y);
        float speed = frameTimeCounter * 1.2;

        float displacementX = sin(speed + (worldPos.x + worldPos.y) * 0.5) * 0.1;
        float displacementZ = cos(speed * 0.8 + (worldPos.z + worldPos.y) * 0.5) * 0.08;

        viewPos.x += displacementX * heightFactor;
        viewPos.z += displacementZ * heightFactor;
        gl_Position = gl_ProjectionMatrix * viewPos;
    } else if (abs(blockID - 4.0) < 1.0) { // leaves
        vec4 worldPos = gbufferModelViewInverse * viewPos;
        float speed = frameTimeCounter * 2.0; 
        float shakeX = sin(speed + (worldPos.x + worldPos.y + worldPos.z) * 2.0) * 0.02;
        float shakeZ = cos(speed * 1.1 + (worldPos.x - worldPos.y + worldPos.z) * 1.5) * 0.001;

        viewPos.x += shakeX;
        viewPos.z += shakeZ;
        gl_Position = gl_ProjectionMatrix * viewPos;
    } else {
        // Default to standard transform for all other blocks (like terrain)
        gl_Position = ftransform();
    }
}