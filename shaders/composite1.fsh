#version 330 compatibility

#include /lib/distort.glsl
#include /lib/util.glsl

in vec2 texcoord;

#define FOG_DENSITY 5.0

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	color = texture(colortex0, texcoord);

	float depth = texture(depthtex0, texcoord).r;
	if(depth == 1.0){
		return;
	}

  vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);

  float dist = length(viewPos) / far;
  float fogFactor = exp(-FOG_DENSITY * (1.0 - dist));

  color.rgb = mix(color.rgb, pow(fogColor, vec3(2.2)), clamp(fogFactor, 0.0, 1.0));
}