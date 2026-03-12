#version 330 compatibility
#include /lib/distort.glsl
#include /lib/util.glsl

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform sampler2D noisetex;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform float sunAngle;
uniform int worldTime;


uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

const vec3 blocklightColor = vec3(1.0, 0.5, 0.125);
const vec3 skylightColor = vec3(1.0);
const vec3 sunlightColor = vec3(1.0);
const vec3 sunlightScatterColor = vec3(1.0, 0.4, 0.1);
const vec3 moonlightColor = vec3(1.0);
const vec3 ambientColor = vec3(0.1);

const float shadowDistanceRenderMul = 1.0;


vec3 getShadow(vec3 shadowScreenPos){
  float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r); // sample the shadow map containing everything

  /*
  note that a value of 1.0 means 100% of sunlight is getting through
  not that there is 100% shadowing
  */

  if(transparentShadow == 1.0){
    /*
    since this shadow map contains everything,
    there is no shadow at all, so we return full sunlight
    */
    return vec3(1.0);
  }

  float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r); // sample the shadow map containing only opaque stuff

  if(opaqueShadow == 0.0){
    // there is a shadow cast by something opaque, so we return no sunlight
    return vec3(0.0);
  }

  // contains the color and alpha (transparency) of the thing casting a shadow
  vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);


  /*
  we use 1 - the alpha to get how much light is let through
  and multiply that light by the color of the caster
  */
  return shadowColor.rgb * (1.0 - shadowColor.a);
}

vec4 getNoise(vec2 coord){
  ivec2 screenCoord = ivec2(coord * vec2(viewWidth, viewHeight)); // exact pixel coordinate onscreen
  ivec2 noiseCoord = screenCoord % 64; // wrap to range of noiseTextureResolution
  return texelFetch(noisetex, noiseCoord, 0);
}

vec3 getSoftShadow(vec4 shadowClipPos){
  vec3 shadowAccum = vec3(0.0); // sum of all shadow samples
  const int samples = SHADOW_RANGE * SHADOW_RANGE * 4; // we are taking 2 * SHADOW_RANGE * 2 * SHADOW_RANGE samples

  float noise = getNoise(texcoord).r;
  float theta = noise * radians(360.0);
  float cosTheta = cos(theta);
  float sinTheta = sin(theta);

  mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);


  for(int x = -SHADOW_RANGE; x < SHADOW_RANGE; x++){
    for(int y = -SHADOW_RANGE; y < SHADOW_RANGE; y++){
      vec2 offset = vec2(x, y) * SHADOW_RADIUS / float(SHADOW_RANGE);
	  offset = rotation * offset;
      offset /= shadowMapResolution; // offset in the rotated direction by the specified amount. We divide by the resolution so our offset is in terms of pixels
      vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, 0.0, 0.0); // add offset
      offsetShadowClipPos.z -= 0.001; // apply bias
      offsetShadowClipPos.xyz = distortShadowClipPos(offsetShadowClipPos.xyz); // apply distortion
      vec3 shadowNDCPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w; // convert to NDC space
      vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5; // convert to screen space
      shadowAccum += getShadow(shadowScreenPos); // take shadow sample
    }
  }

  return shadowAccum / float(samples); // divide sum by count, getting average shadow
}

float getLightContribution(vec3 lightDir) {
    // lightDir is the normalized vector of the sun or moon in Player Space
    // The 'y' component is the height above the horizon (-1.0 to 1.0)
    
    float height = lightDir.y;
    
    // Smoothly transition as it nears the horizon
    // Using smoothstep prevents a sharp "pop" when the sun hits 0.0
    return smoothstep(0, 0.1, height);
}

vec3 getCelestialLight(vec3 normal, vec3 shadow) {
  vec3 sunVec = normalize(sunPosition);
	vec3 worldSunVector = mat3(gbufferModelViewInverse) * sunVec;
  vec3 moonVec = normalize(moonPosition);
	vec3 worldMoonVector = mat3(gbufferModelViewInverse) * moonVec;

  // Inside main() or a lighting function
  float sunIntensity = getLightContribution(worldSunVector);
  float moonIntensity = getLightContribution(worldMoonVector);

  // Example colors (Warm Sun, Cold Moon)
  vec3 sunlightContribution = mix(sunlightScatterColor, sunlightColor, smoothstep(0.0, 0.3, worldSunVector.y)) * sunIntensity;
  vec3 moonlightContribution = moonlightColor * moonIntensity;

  float moonLightFactor = 0.05;
  float sunLightFactor = 1.0;
  return  (sunlightContribution * shadow)*sunLightFactor + (moonlightContribution * shadow)*moonLightFactor;
}

uniform float near; // near viewing plane distance                   
uniform float far; // far viewing plane distance

float linearizeDepth(float depth) {
    float z = depth * 2.0 - 1.0; // convert to NDC
    return (2.0 * near * far) / (far + near - z * (far - near));
}

void main() {
	
	color = texture(colortex0, texcoord);
	color.rgb = pow(color.rgb, vec3(2.2));
	float depth = texture(depthtex0, texcoord).r; 
	float depth_underwater = texture(depthtex1, texcoord).r; // depth1 is the seabed (or whatever is behind the water)
  float waterThickness = max(depth_underwater - depth, 0.0);
	if (depth == 1.0) {
		return;
	}
	vec2 lightmap = texture(colortex1, texcoord).rg; // we only need the r and g components
	vec3 encodedNormal = texture(colortex2, texcoord).rgb;
	vec3 normal = normalize((encodedNormal - 0.5) * 2.0); // we normalize to make sure it is of unit length
	
	vec3 blocklight = lightmap.r * blocklightColor;
	vec3 skylight = lightmap.g * skylightColor;
	vec3 ambient = ambientColor;

	
	vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);

	vec3 shadow = getSoftShadow(shadowClipPos);
	vec3 sunlight = getCelestialLight(normal, shadow);

	color.rgb *= blocklight + (sunlight)*skylight;

  if (waterThickness > 0.000001) {
    vec3 absorption = (1 - exp(-waterThickness * vec3(450.0, 500.0, 650.0)));
    color.rgb *= absorption;
  }
}
