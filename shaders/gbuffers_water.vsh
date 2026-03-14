#version 330 compatibility

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;

uniform mat4 gbufferModelViewInverse;

void main() {
	// Standard vertex transformation
	gl_Position = ftransform();

	// Pass texture coordinates for water foam/flowing textures
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	// Pass lightmap coordinates (needed for blocklight/skylight on the surface)
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	// Apply the same correction used in your other shaders
	lmcoord = lmcoord / (30.0 / 32.0) - (1.0 / 32.0); 

	// Capture the BIOME COLOR (this is the key for your request)
	glcolor = gl_Color;

	// Transform normals to Player Space for consistent shading/reflections
	normal = gl_NormalMatrix * gl_Normal;
	normal = mat3(gbufferModelViewInverse) * normal;
}