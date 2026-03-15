#version 330 compatibility

#include /lib/distort.glsl
#include /lib/util.glsl

in vec2 texcoord;
uniform int isEyeInWater;

const vec3 waterDensity = vec3(0.1, 0.05, 0.02);
const vec3 sunlightColor = vec3(1.0);

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

vec3 getSpecular(vec3 normal, vec3 viewDir, vec3 sunDir) {
    vec3 halfDir = normalize(sunDir - viewDir); // Blinn-Phong half-vector
    float spec = pow(max(0.0, dot(normal, halfDir)), 128.0); // 128.0 = shininess
    
    // Use sunlight color and mask it by the sun's intensity (height)
    float sunIntensity = smoothstep(0.0, 0.1, sunDir.y);
    return sunlightColor * spec * sunIntensity;
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
    // Fallback: If no blocks hit, reflect the sky
    return skyColor;
}

void main() {
	color = texture(colortex0, texcoord);
	float depth = texture(depthtex0, texcoord).r;
	if(depth == 1.0){
		return;
	}

    vec3 encodedNormal = texture(colortex2, texcoord).rgb;
	vec3 normal = normalize((encodedNormal - 0.5) * 2.0); // we normalize to make sure it is of unit length

    vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
    vec3 viewDir = normalize(viewPos);
    float depth_underwater = texture(depthtex1, texcoord).r; // depth1 is the seabed (or whatever is behind the water)
    if(depth_underwater > depth) {
        vec3 world_depth = projectAndDivide(gbufferProjectionInverse, vec3(texcoord, depth) * 2.0 - 1.0);
        vec3 world_water_depth = projectAndDivide(gbufferProjectionInverse, vec3(texcoord, depth_underwater) * 2.0 - 1.0);
        float waterThickness = length(world_water_depth - world_depth);
        if (waterThickness > 0.000001) {
            vec3 absorption = exp(waterThickness * -waterDensity);
            color.rgb *= absorption;
        }
        if (isEyeInWater == 0) {
            vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
            // Add the camera's world coordinates to get the absolute World Position
            vec3 worldPos = feetPlayerPos + cameraPosition;
            vec3 waterNormal = getWaterNormal(worldPos);
            // Transform the water normal from World Space to View Space
            // This allows it to work with our viewDir and reflectDir
            vec3 perturbedNormal = mat3(gbufferModelView) * waterNormal;
            perturbedNormal = normalize(perturbedNormal);
            // water reflection calculations
            vec3 reflectDir = reflect(viewDir, perturbedNormal);
            float lightCosTheta = dot(perturbedNormal, -viewDir);
            float fresnel = 0.02 + 0.98 * pow(1.0 - clamp(lightCosTheta, 0.0, 1.0), 5.0);
            vec3 reflectionColor = getReflection(viewPos, reflectDir);

        if(reflectionColor != vec3(0.0)) {
            color.rgb = mix(color.rgb, reflectionColor, fresnel);
        }
        vec3 sunDir = normalize(sunPosition);
        vec3 specular = getSpecular(normal, viewDir, sunDir);
        color.rgb += specular;
        }
    
    }

    if (isEyeInWater == 1) {
        float viewDist = -viewPos.z;

        float fog = 1.0 - exp(-viewDist * 0.045);

        // reduce fog when looking up
        float upFactor = clamp(viewDir.y * 0.5 + 0.5, 0.0, 1.0);
        fog *= mix(1.0, 0.9, upFactor);

        vec3 fog_color = pow(fogColor, vec3(2.2));
        fog_color = mix(vec3(0.02, 0.08, 0.12), fog_color, 0.4);

        color.rgb = mix(color.rgb, fog_color, fog);
    } 
}