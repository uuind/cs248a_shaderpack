#version 330 compatibility

#include /lib/distort.glsl
#include /lib/util.glsl

in vec2 texcoord;
uniform int isEyeInWater;

uniform sampler2D colortex3;

#define ETA_AIR 1.0
#define ETA_WATER 1.33

const vec3 waterDensity = vec3(0.1, 0.05, 0.02);
const vec3 sunlightColor = vec3(1.0);

uniform int viewWidth;
uniform int viewHeight;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

vec3 getSpecular(vec3 normal, vec3 viewDir, vec3 sunDir) {
    vec3 halfDir = normalize(sunDir - viewDir); // Blinn-Phong half-vector
    float spec = pow(max(0.0, dot(normal, halfDir)), 128.0); // 128.0 = shininess
    float horizonMask = smoothstep(-0.05, 0.05, sunDir.y);
    // Use sunlight color and mask it by the sun's intensity (height)
    float sunIntensity = smoothstep(0.0, 0.1, sunDir.y);
    return sunlightColor * spec * sunIntensity;
}


vec3 sampleReflection(vec3 viewPos, vec3 awayDir, bool underwater, float waterSurface) {
    // 1. Nudge the ray to prevent self-intersection
    vec3 currentPos = viewPos + awayDir * 0.4; 
    
    // 2. Adjust step size for performance vs. quality
    // Increasing this will help you get back to 144 FPS
    float stepSize = 0.5; 
    int maxSteps = 600; // Significantly reduced from 400 for efficiency

    for(int i = 0; i < maxSteps; i++) {
        currentPos += awayDir * stepSize;

        // 3. Project to Screen Space
        vec4 projectPos = gbufferProjection * vec4(currentPos, 1.0);
        
        // Critical: Perspective divide happens once per step
        vec3 screenPos = (projectPos.xyz / projectPos.w) * 0.5 + 0.5;

        // 4. Boundary check
        if(screenPos.x < 0.0 || screenPos.x > 1.0 || screenPos.y < 0.0 || screenPos.y > 1.0) break;

        // 5. Comparison using Linear View-Space Z
        float rawDepth = texture(depthtex1, screenPos.xy).r;
        if (rawDepth == 1.0) break; // Hit the sky, stop marching

        // Reconstruct the scene depth at this specific pixel
        vec3 sceneViewPos = projectAndDivide(gbufferProjectionInverse, vec3(screenPos.xy, rawDepth) * 2.0 - 1.0);

        // In View Space, Z is negative. A 'hit' is when the ray is further (more negative) than the scene
        if(currentPos.z < sceneViewPos.z) {
            return texture(colortex0, screenPos.xy).rgb; // Return the color of the hit pixel plus some sky color for a more natural reflection

        }
    }
    // For reflections, if we miss, we can return the sky color for a more natural look
    return pow(skyColor, vec3(2.2)) * 0.5; // Dimming the sky reflection for better contrast
}

void main() {
	color = texture(colortex0, texcoord);
	float depth = texture(depthtex0, texcoord).r;
	if(depth == 1.0){
		return;
	}

    vec4 encodedNormal = texture(colortex2, texcoord);
	vec3 normal = normalize((encodedNormal.rgb - 0.5) * 2.0); // we normalize to make sure it is of unit length

    vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
    vec3 viewDir = normalize(viewPos);
    float blockID = texture(colortex3, texcoord).r * 65535.0;
    float depth_underwater = texture(depthtex1, texcoord).r; // depth1 is the seabed (or whatever is behind the water)
    if(abs(blockID - 10000.0) < 50.0) {
        if(depth_underwater > depth) {

            vec3 waterSurfaceViewPos = viewPos; 
            vec3 waterSurfaceWorldPos = (gbufferModelViewInverse * vec4(waterSurfaceViewPos, 1.0)).xyz + cameraPosition;
            float waterY = waterSurfaceWorldPos.y;

            vec3 world_depth = projectAndDivide(gbufferProjectionInverse, vec3(texcoord, depth) * 2.0 - 1.0);
            vec3 world_water_depth = projectAndDivide(gbufferProjectionInverse, vec3(texcoord, depth_underwater) * 2.0 - 1.0);
            float waterThickness = length(world_water_depth - world_depth);
            if (waterThickness > 0.000001) {
                vec3 absorption = exp(waterThickness * -waterDensity);
                color.rgb *= absorption;
            }
            // underwater
            vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
            vec3 worldPos = feetPlayerPos + cameraPosition;
            vec3 waterNormal = getWaterNormal(worldPos);
            vec3 perturbedNormal = normalize(mat3(gbufferModelView) * waterNormal);
            
        
            float eta = ETA_WATER/ETA_AIR;

            
            float cosTheta = clamp(dot(-viewDir, perturbedNormal), 0.0, 1.0);
            
            float sinThetaT = eta * sqrt(max(0.0, 1.0 - cosTheta * cosTheta));

            bool totalInternalReflection = sinThetaT > 1.0;

            float fresnel = 0.02 + 0.98 * pow(1.0 - cosTheta, 5.0);
            fresnel = clamp(fresnel, 0.02, 1.0);
            
            vec3 reflectionColor = vec3(0.0);
            
            if (isEyeInWater == 0) {
                reflectionColor = sampleReflection(viewPos, reflect(viewDir, perturbedNormal), false, waterY);
                if(dot(reflectionColor, reflectionColor) > 0) {
                    color.rgb = mix(color.rgb, reflectionColor, fresnel);
                }
                vec3 sunDir = normalize(sunPosition);
                vec3 specular = getSpecular(perturbedNormal, viewDir, sunDir);
                color.rgb += specular;
            } else {
                reflectionColor = sampleReflection(viewPos, reflect(viewDir, perturbedNormal), true, waterY);
                if(dot(reflectionColor, reflectionColor) > 0 && totalInternalReflection) {
                    color.rgb = mix(color.rgb, reflectionColor, fresnel);
                }
            }
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