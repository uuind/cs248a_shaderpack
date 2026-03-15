uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform vec3 fogColor;

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

vec3 getReflection(vec3 viewPos, vec3 reflectDir) {
    // Offset the start: Nudge the ray away from the water surface
    // to prevent it from hitting the pixel it just left.
    vec3 currentPos = viewPos + reflectDir * 0.5; 
    float stepSize = 0.1; 

    for(int i = 0; i < 400; i++) {
        currentPos += reflectDir * stepSize;

        // Project the ray's 3D position to 2D Screen Space
        vec4 projectPos = gbufferProjection * vec4(currentPos, 1.0);
        vec3 screenPos = (projectPos.xyz / projectPos.w) * 0.5 + 0.5;

        // Boundary check: If the ray leaves the screen, stop
        if(screenPos.x < 0.0 || screenPos.x > 1.0 || screenPos.y < 0.0 || screenPos.y > 1.0) break;

        // Sample the OPAQUE depth (seabed/terrain)
        float rawDepth = texture(depthtex1, screenPos.xy).r;
        if (rawDepth == 1.0) continue; // Skip the sky

        // Convert raw depth to Linear View Space Z (meters)
        vec3 sceneViewPos = projectAndDivide(gbufferProjectionInverse, vec3(screenPos.xy, rawDepth) * 2.0 - 1.0);

        // Comparison: In OpenGL, Z is negative (0 is camera, -100 is far)
        // A hit occurs if the ray's Z is 'further' (smaller) than the scene Z
        if(currentPos.z < sceneViewPos.z) {
            // Check thickness to avoid reflecting through walls
            if(abs(currentPos.z - sceneViewPos.z) < 1.0) {
                return texture(colortex0, screenPos.xy).rgb;
            }
        }
    }
    // Fallback: If no blocks hit, reflect the atmospheric fog
    return pow(fogColor, vec3(2.2));
}