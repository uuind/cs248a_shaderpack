uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

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

