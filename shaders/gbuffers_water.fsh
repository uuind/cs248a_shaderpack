#version 330 compatibility

uniform sampler2D gtexture;
uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;

/* RENDERTARGETS: 0,1,2 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;

void main() {
    // 1. Get the base texture and multiply by the biome tint (glcolor)
    vec4 tex = texture(gtexture, texcoord);
    color = tex * glcolor;

    // 2. Store the lightmap coordinates (needed for surface brightness)
    lightmapData = vec4(lmcoord, 0.0, 1.0);

    // 3. Encode the normals into a 0.0 to 1.0 range
    // We use the player-space normal for path-traced reflections later
    encodedNormal = vec4(normal * 0.5 + 0.5, 1.0);

    // 4. Alpha Testing
    // Discard pixels that are too transparent (like water edge gaps)
    if (color.a < alphaTestRef) {
        discard;
    }
}