#version 330 compatibility

#include /lib/distort.glsl
#include /lib/util.glsl

/* RENDERTARGETS: 0,1,2 */
// Changed names to avoid conflict with the 'color' varying from Minecraft
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLightmap;
layout(location = 2) out vec4 outNormal;

uniform sampler2D gtexture;

in vec2 texcoord;
in vec3 normal;
in vec4 glcolor; // This is the vertex color from the CPU
in vec4 viewPos;


void main() {
    // 1. Get world position for the waves
    vec3 playerPos = (gbufferModelViewInverse * viewPos).xyz;
    vec3 worldPos = playerPos + cameraPosition;

    // 2. Calculate the perturbed normal
    vec3 waterNormal = getWaterNormal(worldPos);
    
    // 3. Simple Alpha/Opacity logic
    float alpha = 0.4; 

    // 4. Sample the base water texture (biome color)
    // Use 'texture()' instead of 'texture2D()' for version 330
    vec4 albedo = texture(gtexture, texcoord) * glcolor;

    // Output to the G-buffer using the layout locations defined above
    outColor = vec4(albedo.rgb, alpha); 
    outLightmap = vec4(0.0); 
    outNormal = vec4(waterNormal * 0.5 + 0.5, 1.0); 
}