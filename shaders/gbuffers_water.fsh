#version 330 compatibility

#include /lib/distort.glsl
#include /lib/util.glsl

/* RENDERTARGETS: 0,1,2,3 */
// Changed names to avoid conflict with the 'color' varying from Minecraft
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmap;
layout(location = 2) out vec4 outNormal;
layout(location = 3) out vec4 outData; // New buffer for IDs

uniform sampler2D gtexture;

in vec2 texcoord;
in vec3 normal;
in vec4 glcolor; // This is the vertex color from the CPU
in vec4 viewPos;
in vec2 lmcoord;
flat in float blockID;




void main() {
    vec3 playerPos = (gbufferModelViewInverse * viewPos).xyz;
    vec3 worldPos = playerPos + cameraPosition;

    // Use the 330-style texture sampling
    vec4 texColor = texture(gtexture, texcoord);
    vec4 albedo = texColor * glcolor;
    
    outData = vec4(blockID/BLOCK_ID_RANGE, 0.0, 0.0, 1.0);
    if(abs(blockID - 1.0) < 1.0) {
        // Water Logic
        vec3 waterNormal = getWaterNormal(worldPos);
        outColor = vec4(albedo.rgb, 0.4); // opacity of 0.4
        outLightmap = vec4(0.0);
        outNormal = vec4(waterNormal * 0.5 + 0.5, 1.0);
    } else {
        // Glass/Other Translucent Logic
        // Use texColor directly to avoid double-multiplying by glcolor if not needed
        outColor = texColor; 
        outLightmap = vec4(lmcoord, 0.0, 1.0);
        outNormal = vec4(normal * 0.5 + 0.5, 0.0);
    }
}