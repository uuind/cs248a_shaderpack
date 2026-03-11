const int shadowMapResolution = 4096;

const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowcolor0Nearest = true;

#define SHADOW_RADIUS 1
#define SHADOW_RANGE 4


vec3 distortShadowClipPos(vec3 shadowClipPos){
  float l = length(shadowClipPos.xy);
    
  // The 'distortionAmount' controls how much resolution is pulled to the center.
  // 0.9 is generally a good sweet spot for 4096 resolution.
  float distortionAmount = 0.9; 
  float distortionFactor = (1.0 - distortionAmount) + l * distortionAmount;
  distortionFactor += 0.1; // very small distances can cause issues so we add this to slightly reduce the distortion

  shadowClipPos.xy /= distortionFactor;
  shadowClipPos.z *= 0.5; // increases shadow distance on the Z axis, which helps when the sun is very low in the sky
  return shadowClipPos;
}