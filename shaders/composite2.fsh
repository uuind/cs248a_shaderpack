#version 330 compatibility

#include /lib/distort.glsl
#include /lib/util.glsl

in vec2 texcoord;
uniform int isEyeInWater;

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


vec3 sampleCaustics(vec3 viewPos, vec3 awayDir, bool isReflection) {
    // 1. Nudge the ray to prevent self-intersection
    vec3 currentPos = viewPos + awayDir * 0.4; 
    
    // 2. Adjust step size for performance vs. quality
    // Increasing this will help you get back to 144 FPS
    float stepSize = 0.8; 
    int maxSteps = 400; // Significantly reduced from 400 for efficiency

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
            // Thickness check to prevent rays from 'bleeding' through thin walls
            if(abs(currentPos.z - sceneViewPos.z) < 2.0) {
                return texture(colortex0, screenPos.xy).rgb;
            }
        }
    }
    if(isReflection) {
        // For reflections, if we miss, we can return the sky color for a more natural look
        return skyColor;
    } else {
        // For refractions, if we miss, we return black (or you could choose a subtle tint)
        return vec3(0.0);
    }
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
        // underwater
        vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 worldPos = feetPlayerPos + cameraPosition;
        vec3 waterNormal = getWaterNormal(worldPos);
        vec3 perturbedNormal = normalize(mat3(gbufferModelView) * waterNormal);
        
        float eta;
        if(isEyeInWater == 1) {
            eta = ETA_AIR / ETA_WATER;
        } else {
            eta = ETA_WATER / ETA_AIR;
        }

        // gl_FragCoord.xy gives the actual pixel integer coordinates (e.g., 1920, 1080)
        uint seed = uint(gl_FragCoord.x) * uint(viewWidth) + uint(gl_FragCoord.y) * uint(viewHeight);

        // Combine pixel index with time to ensure it changes every frame
        

        
        float cosTheta = clamp(dot(-viewDir, perturbedNormal), 0.0, 1.0);
        
        float sinThetaT = eta * sqrt(max(0.0, 1.0 - cosTheta * cosTheta));

        bool totalInternalReflection = sinThetaT > 1.0;

        float fresnel = 0.02 + 0.98 * pow(1.0 - cosTheta, 5.0);
        fresnel = clamp(fresnel, 0.02, 1.0);
        
        vec3 reflectionColor = vec3(0.0);
        vec3 refractionColor = vec3(0.0);
        if(rand(seed) < fresnel) {
            reflectionColor = sampleCaustics(viewPos, reflect(viewDir, perturbedNormal), true);
        } else {
            refractionColor = sampleCaustics(viewPos, refract(viewDir, perturbedNormal, eta), false);
        }

        if(dot(refractionColor, refractionColor) > 1e-6 && !totalInternalReflection) {
            color.rgb = mix(color.rgb, refractionColor, 1.0 - fresnel);
        }
        if(dot(reflectionColor, reflectionColor) > 1e-6) {
            color.rgb = mix(color.rgb, reflectionColor, fresnel);
        }
        
        if (isEyeInWater == 0) {
            vec3 sunDir = normalize(sunPosition);
            vec3 specular = getSpecular(perturbedNormal, viewDir, sunDir);
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