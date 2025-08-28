varying vec2 vUvs;
varying vec3 vNormal;
uniform vec2 resolution;
uniform float time;
uniform vec2 uMousePos;

float inverseLerp(float v, float minValue, float maxValue) {
  return (v - minValue) / (maxValue - minValue);
}

float remap(float v, float inMin, float inMax, float outMin, float outMax) {
  float t = inverseLerp(v, inMin, inMax);
  return mix(outMin, outMax, t);
}
float sdfCircle(vec2 p, float r) {
  return length(p) - r;
}
float softMax(float a, float b, float k) {
  return log(exp(k * a) + exp(k * b)) / k;
}

float softMin(float a, float b, float k) {
  return -softMax(-a, -b, k);
}
// The MIT License
// Copyright © 2013 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// https://www.youtube.com/c/InigoQuilez
// https://iquilezles.org/
//
// https://www.shadertoy.com/view/Xsl3Dl
vec3 hash(vec3 p) // replace this by something better
{
  p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));

  return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(in vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);

  vec3 u = f * f * (3.0 - 2.0 * f);

  return mix(mix(mix(dot(hash(i + vec3(0.0, 0.0, 0.0)), f - vec3(0.0, 0.0, 0.0)), dot(hash(i + vec3(1.0, 0.0, 0.0)), f - vec3(1.0, 0.0, 0.0)), u.x), mix(dot(hash(i + vec3(0.0, 1.0, 0.0)), f - vec3(0.0, 1.0, 0.0)), dot(hash(i + vec3(1.0, 1.0, 0.0)), f - vec3(1.0, 1.0, 0.0)), u.x), u.y), mix(mix(dot(hash(i + vec3(0.0, 0.0, 1.0)), f - vec3(0.0, 0.0, 1.0)), dot(hash(i + vec3(1.0, 0.0, 1.0)), f - vec3(1.0, 0.0, 1.0)), u.x), mix(dot(hash(i + vec3(0.0, 1.0, 1.0)), f - vec3(0.0, 1.0, 1.0)), dot(hash(i + vec3(1.0, 1.0, 1.0)), f - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
}

float fbm(vec3 p, int octaves, float persistence, float lacunarity) {
  float amplitude = 0.5;
  float frequency = 1.0;
  float total = 0.0;
  float normalization = 0.0;

  for(int i = 0; i < octaves; ++i) {
    float noiseValue = noise(p * frequency);
    total += noiseValue * amplitude;
    normalization += amplitude;
    amplitude *= persistence;
    frequency *= lacunarity;
  }

  total /= normalization;

  return total;
}
float cellular(vec3 coords) {
  vec2 gridBasePosition = floor(coords.xy);
  vec2 gridCoordOffset = fract(coords.xy);

  float closest = 1.0;
  for(float y = -2.0; y <= 2.0; y += 1.0) {
    for(float x = -2.0; x <= 2.0; x += 1.0) {
      vec2 neighbourCellPosition = vec2(x, y);
      vec2 cellWorldPosition = gridBasePosition + neighbourCellPosition;
      vec2 cellOffset = vec2(noise(vec3(cellWorldPosition, coords.z) + vec3(243.432, 324.235, 0.0)), noise(vec3(cellWorldPosition, coords.z)));

      float distToNeighbour = length(neighbourCellPosition + cellOffset - gridCoordOffset);
      closest = min(closest, distToNeighbour);
    }
  }

  return closest;
}
float turbulenceFBM(vec3 p, int octaves, float persistence, float lacunarity) {
  float amplitude = 0.5;
  float frequency = 1.0;
  float total = 0.0;
  float normalization = 0.0;

  for(int i = 0; i < octaves; ++i) {
    float noiseValue = noise(p * frequency);
    noiseValue = abs(noiseValue);

    total += noiseValue * amplitude;
    normalization += amplitude;
    amplitude *= persistence;
    frequency *= lacunarity;
  }

  total /= normalization;

  return total;
}
void main() {
  float persistance = 15.0;
  float lacunarity = 2.0;
  int octaves = 2;
  float noiseMultiply = 170.0;
  vec2 offsetUvs = (vUvs - 0.5);
  vec2 pixelCoords = offsetUvs * resolution;
  // noise
  vec3 coords = vec3(pixelCoords / 150., time * 0.2);
  float noiseSample = remap(turbulenceFBM(coords, octaves, persistance, lacunarity), -1.0, 1.0, 0.0, 1.0);

  //normal gneration
  vec3 pixel = vec3(0.5 / resolution , 0.0);

  float s1 = turbulenceFBM(coords + pixel.xzz, octaves, persistance, lacunarity);
  float s2 = turbulenceFBM(coords - pixel.xzz, octaves, persistance, lacunarity);
  float s3 = turbulenceFBM(coords + pixel.zyz, octaves, persistance, lacunarity);
  float s4 = turbulenceFBM(coords - pixel.zyz, octaves, persistance, lacunarity);
  vec3 normal = normalize(vec3(s1 - s2, s3 - s4, 0.005));
  //SDF circles

  vec2 pos = pixelCoords;
  pos -= uMousePos;
  float d1 = sdfCircle(pos, 150.0 + noiseSample * noiseMultiply);
  float d2 = sdfCircle(pixelCoords, 150.0 + noiseSample * noiseMultiply);

  //union
  float d = softMin(d1, d2, 0.01);

    // Hemi
  vec3 skyColour = vec3(0.0, 0.3, 0.6);
  vec3 groundColour = vec3(0.6, 0.3, 0.1);

  vec3 hemi = mix(groundColour, skyColour, remap(normal.y, -1.0, 1.0, 0.0, 1.0));

  // Diffuse lighting
  vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));
  vec3 lightColour = vec3(1.0, 1.0, 0.9);
  float dp = max(0.0, dot(lightDir, normal));

  vec3 diffuse = dp * lightColour;
  vec3 specular = vec3(0.0);

  // Specular
  vec3 r = normalize(reflect(-lightDir, normal));
  float phongValue = max(0.0, dot(vec3(0.0, 0.0, 1.0), r));
  phongValue = pow(phongValue, 32.0);

  specular += phongValue *0.5;

  //color
  vec3 colour = mix(vec3(1.0, 0.25, 0.25), vec3(0.0, 0.0, 0.0), noiseSample);
  colour = pow(colour, vec3(2.));
  vec3 lighting = hemi * 0.125 + diffuse * 0.5;

  colour = colour * lighting + specular;
  colour = pow(colour, vec3(1.0 / 2.2));
  colour = mix(colour, vec3(0.0), smoothstep(0.0, 1.0, d));
  colour = pow(colour, vec3( 1.5));
  gl_FragColor = vec4(colour, 1.0);
}