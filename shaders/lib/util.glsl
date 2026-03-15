uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform sampler2D noisetex;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform int worldTime;

uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform vec3 skyColor;
uniform vec3 fogColor;

uniform vec3 cameraPosition;

uniform float near; // near viewing plane distance                   
uniform float far; // far viewing plane distance

const float PI = 3.1415926535;

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
  vec4 homPos = projectionMatrix * vec4(position, 1.0);
  return homPos.xyz / homPos.w;
}

// Reconstructs the position of the pixel relative to the player
vec3 screenToPlayerSpace(vec2 uv, float depth) {
    // Convert UV and Depth to Normalized Device Coordinates (NDC) range [-1.0, 1.0]
    vec4 ndcPos = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);

    // Transform NDC to View Space using the Inverse Projection Matrix
    vec4 viewPos = gbufferProjectionInverse * ndcPos;
    
    //Perspective Divide (crucial for perspective projections)
    viewPos /= viewPos.w;

    //Transform View Space to Player Space (relative to camera)
    vec4 playerPos = gbufferModelViewInverse * viewPos;

    return playerPos.xyz;
}


vec3 getWaterNormal(vec3 worldPos) {
    // 1. Static coordinates (Back to your preferred scales)
    vec2 coord1 = worldPos.xz * 0.0005; 
    vec2 coord2 = worldPos.xz * 0.0013; 
    vec2 coord3 = worldPos.xz * 0.0023;
    
    // 2. Linear time for constant flowing movement
    // Reduced from 0.1 to 0.04 to prevent the "too fast" feeling
    float time = float(worldTime) * 0.0005; 

    // 3. Offset the coordinates over time to create the "Flow"
    // We use different directions for each layer to make it look organic
    vec2 flow1 = vec2(time * 0.2, time * 0.1);
    vec2 flow2 = vec2(time * -0.1, time * 0.2);
    vec2 flow3 = vec2(time * 0.15, time * -0.15);

    // 4. Sample and mix height values
    float n1 = texture(noisetex, coord1 + flow1).r;
    float n2 = texture(noisetex, coord2 + flow2).r;
    float n3 = texture(noisetex, coord3).r; // Keep one layer static for grounding
    
    float combinedHeight = (n1 + n2 + n3) / 3.0;

    // 5. Calculate slopes (Normals)
    float delta = 0.001;
    float hX = (texture(noisetex, coord1 + vec2(delta, 0.0) + flow1).r + 
                texture(noisetex, coord2 + vec2(delta, 0.0) + flow2).r + 
                texture(noisetex, coord3 + vec2(delta, 0.0)).r) / 3.0;

    float hY = (texture(noisetex, coord1 + vec2(0.0, delta) + flow1).r + 
                texture(noisetex, coord2 + vec2(0.0, delta) + flow2).r + 
                texture(noisetex, coord3 + vec2(0.0, delta)).r) / 3.0;
    
    // Using your stabilizing 1.2 Y value
    vec3 waveNormal = normalize(vec3(combinedHeight - hX, 1.2, combinedHeight - hY));
    return waveNormal;
}