varying vec2 vUvs;
uniform vec2 resolution;
uniform float time;
const int TRAIL_LENGTH = 20;
uniform vec2 uPointerTrail[TRAIL_LENGTH];

const vec3 PINK = vec3(0.851, 0.612, 0.788);
const vec3 PINKY_BROWN = vec3(0.749, 0.639, 0.722); //#BFA3B8
const vec3 VIOLET = vec3(0.329, 0.341, 0.549); //#54578C
const vec3 BLUE = vec3(0.247, 0.373, 0.749);//#3F5FBF
const vec3 BEIGE = vec3(0.957, 0.765, 0.737);//#F4C3BC
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
float sdBox(in vec2 p, in vec2 b) {
  vec2 d = abs(p) - b;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdEllipse(in vec2 p, in vec2 ab) {
  p = abs(p);
  if(p.x > p.y) {
    p = p.yx;
    ab = ab.yx;
  }
  float l = ab.y * ab.y - ab.x * ab.x;
  float m = ab.x * p.x / l;
  float m2 = m * m;
  float n = ab.y * p.y / l;
  float n2 = n * n;
  float c = (m2 + n2 - 1.0) / 3.0;
  float c3 = c * c * c;
  float q = c3 + m2 * n2 * 2.0;
  float d = c3 + m2 * n2;
  float g = m + m * n2;
  float co;
  if(d < 0.0) {
    float h = acos(q / c3) / 3.0;
    float s = cos(h);
    float t = sin(h) * sqrt(3.0);
    float rx = sqrt(-c * (s + t + 2.0) + m2);
    float ry = sqrt(-c * (s - t + 2.0) + m2);
    co = (ry + sign(l) * rx + abs(g) / (rx * ry) - m) / 2.0;
  } else {
    float h = 2.0 * m * n * sqrt(d);
    float s = sign(q + h) * pow(abs(q + h), 1.0 / 3.0);
    float u = sign(q - h) * pow(abs(q - h), 1.0 / 3.0);
    float rx = -s - u - c * 4.0 + 2.0 * m2;
    float ry = (s - u) * sqrt(3.0);
    float rm = sqrt(rx * rx + ry * ry);
    co = (ry / sqrt(rm - rx) + 2.0 * g / rm - m) / 2.0;
  }
  vec2 r = ab * vec2(co, sqrt(1.0 - co * co));
  return length(r - p) * sign(p.y - r.y);
}
float softMax(float a, float b, float k) {
  return log(exp(k * a) + exp(k * b)) / k;
}

float softMin(float a, float b, float k) {
  return -softMax(-a, -b, k);
}
float opUnion(float d1, float d2) {
  return min(d1, d2);
}
vec3 hash(vec3 p) {
  p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));

  return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float random(vec2 v) {
    float t = dot(v, vec2(36.5323, 73.945));
  return sin(t);
}
float noise(in vec3 p) {
  vec3 i = floor(p);
  vec3 f = fract(p);

  vec3 u = f * f * (3.0 - 2.0 * f);

  return mix(mix(mix(dot(hash(i + vec3(0.0, 0.0, 0.0)), f - vec3(0.0, 0.0, 0.0)), dot(hash(i + vec3(1.0, 0.0, 0.0)), f - vec3(1.0, 0.0, 0.0)), u.x), mix(dot(hash(i + vec3(0.0, 1.0, 0.0)), f - vec3(0.0, 1.0, 0.0)), dot(hash(i + vec3(1.0, 1.0, 0.0)), f - vec3(1.0, 1.0, 0.0)), u.x), u.y), mix(mix(dot(hash(i + vec3(0.0, 0.0, 1.0)), f - vec3(0.0, 0.0, 1.0)), dot(hash(i + vec3(1.0, 0.0, 1.0)), f - vec3(1.0, 0.0, 1.0)), u.x), mix(dot(hash(i + vec3(0.0, 1.0, 1.0)), f - vec3(0.0, 1.0, 1.0)), dot(hash(i + vec3(1.0, 1.0, 1.0)), f - vec3(1.0, 1.0, 1.0)), u.x), u.y), u.z);
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
vec2 translate(vec2 p, vec2 t) {
  return p - t;
}
vec3 linearTosRGB(vec3 value) {
  vec3 lt = vec3(lessThanEqual(value.rgb, vec3(0.0031308)));

  vec3 v1 = value * 12.92;
  vec3 v2 = pow(value.xyz, vec3(0.41666)) * 1.055 - vec3(0.055);

  return mix(v2, v1, lt);
}
float trail(vec2 pixelCoords, float noiseSample, float noiseFactor) {
  float d1 = 1e5;
  float baseRadius = 8e-3;
  float radius = baseRadius * float(TRAIL_LENGTH);
  float mask = 280.;
  for(int i = 0; i < TRAIL_LENGTH; i++) {
    float fi = float(i);
    vec2 pointerTrail = vec2(uPointerTrail[i].x, -uPointerTrail[i].y);
    pointerTrail = translate(pixelCoords, pointerTrail);
    float sphere = sdfCircle(pointerTrail, radius - baseRadius * fi + noiseSample * noiseFactor) + mask;
    d1 = softMin(d1, sphere, 0.01);
  }
  return d1;
}
float sdBigCloud(vec2 pixelCoords, float noiseSample, float noiseFactor) {
  float puff1 = sdEllipse(pixelCoords, vec2(70.1, 40.) + noiseSample * noiseFactor);
  float puff2 = sdEllipse(translate(pixelCoords, vec2(-200, -20.0)), vec2(30.1, 1.) + noiseSample * noiseFactor);
  float puff3 = sdEllipse(translate(pixelCoords, vec2(200, -20.0)), vec2(30.1, 1.) + noiseSample * noiseFactor);
  return opUnion(opUnion(puff1, puff2), puff3);
}
float sdCloud(vec2 pixelCoords,vec2 ab ,float noiseSample, float noiseFactor) {
  return sdEllipse(pixelCoords, ab + noiseSample * 100.0);
}
void main() {
  float persistance = 15.0;
  float lacunarity = 2.0;
  int octaves = 2;
  float noiseFactor = 170.0;
  vec2 offsetUvs = (vUvs - 0.5);
  vec2 pixelCoords = offsetUvs * resolution;
  // noise
  vec3 coords = vec3(pixelCoords / 150., time * 0.05);
  float noiseSample = remap(turbulenceFBM(coords, octaves, persistance, lacunarity), -1.0, 1.0, 0.0, 1.0);

  //normal gneration
  vec3 pixel = vec3(0.5 / resolution, 0.0);

  float s1 = turbulenceFBM(coords + pixel.xzz, octaves, persistance, lacunarity);
  float s2 = turbulenceFBM(coords - pixel.xzz, octaves, persistance, lacunarity);
  float s3 = turbulenceFBM(coords + pixel.zyz, octaves, persistance, lacunarity);
  float s4 = turbulenceFBM(coords - pixel.zyz, octaves, persistance, lacunarity);
  vec3 normal = normalize(vec3(s1 - s2, s3 - s4, 0.005));

  //SDF clouds
  float d1 = trail(pixelCoords, noiseSample, noiseFactor);
  float d2 = sdBigCloud(translate(pixelCoords, vec2(resolution.x / 2.0 - 250.0, -resolution.y / 2.0 + 70.0)), noiseSample, noiseFactor);

  float d3 = sdBigCloud(translate(pixelCoords, vec2(- resolution.x / 2.0 + 250.0, -resolution.y / 2.0 + 70.0)), noiseSample, noiseFactor);
  float d4 = sdCloud(translate(pixelCoords, vec2(resolution.x / 2.0 - 120.0, -resolution.y / 2.0 + 270.0)),vec2(90.0,10.0), noiseSample, noiseFactor);
  float d5 = sdCloud(translate(pixelCoords, vec2(- resolution.x / 2.0 + 120.0, -resolution.y / 2.0 + 270.0)),vec2(90.0,10.0), noiseSample, noiseFactor);
  

  //union
  float d = softMin(softMin(d1, d2, 0.02), d3, 0.02);
  d = softMin(d,d4,0.02);
  d = softMin(d,d5,0.02);
  
  //Borders clouds
  for(float i = 0.0; i< 5.0; i++){
    float r = sin(i * 12.9898 + time * 0.2) * 0.5 + random(vec2(i));
    float cloud = sdCloud(translate(pixelCoords, vec2(resolution.x / 2.0 - 120.0 + r * 100.0, -resolution.y / 2.0 + 270.0 + i * 100.0)),vec2(10.0,5.0), noiseSample, noiseFactor * 0.2);
    
    float size = mix(2.0, 1.0, random(vec2(i, i + 1.0)));
    float cloud2 = sdCloud(translate(pixelCoords, vec2(-resolution.x / 2.0 + 120.0 + r * 100.0, -resolution.y / 2.0 + 270.0 + i * 100.0)),vec2(size,5.0), noiseSample, noiseFactor *0.2);
    d=softMin(d,cloud,0.02);
    d=softMin(d,cloud2,0.02);

  } 
  //Top and bottom clouds
   for(float i = 0.0; i< 7.0; i++){
    float r = sin(i * 12.9898 + time * 0.2) * 0.5 + random(vec2(i));
    float size = mix(2.0, 1.0, random(vec2(i, i + 1.0)));
    float cloud = sdCloud(translate(pixelCoords, vec2(-resolution.x / 2.0 + i * 400.0 + r * 100.0, resolution.y / 2.0 - 150.0 + r *50.0)),vec2(size,5.0), noiseSample, noiseFactor *0.2);
    float cloud2 = sdCloud(translate(pixelCoords, vec2(-resolution.x / 2.0 + i * 400.0 - r * 100.0, -resolution.y / 2.0 + 150.0 + r *50.0)),vec2(size,5.0), noiseSample, noiseFactor *0.2);
    d=softMin(d,cloud,0.02);
    d=softMin(d,cloud2,0.02);
  } 
    // Hemi
  vec3 skyColour = linearTosRGB(PINK);
  vec3 groundColour = linearTosRGB(BLUE);

  vec3 hemi = mix(groundColour, skyColour, remap(normal.y, -1.0, 1.0, 0.0, 1.0));

  // Diffuse lighting
  vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));
  vec3 lightColour = linearTosRGB(BEIGE);
  float dp = max(0.0, dot(lightDir, normal));

  vec3 diffuse = dp * lightColour;
  vec3 specular = vec3(0.0);

  // Specular
  vec3 r = normalize(reflect(-lightDir, normal));
  float phongValue = max(0.0, dot(vec3(0.0, 0.0, 1.0), r));
  phongValue = pow(phongValue, 32.0);

  specular += phongValue * 0.5;

  // cloud color
  vec3 colour = mix(linearTosRGB(PINK), linearTosRGB(VIOLET), noiseSample);
  colour = mix(colour, linearTosRGB(VIOLET), smoothstep(0.5, 0.75, vUvs.y));
  colour = mix(colour, linearTosRGB(BEIGE), smoothstep(0.7, 0.3, vUvs.y));
  colour = pow(colour, vec3(6.5));

  //light mixing
  vec3 lighting = hemi * 1.0 + diffuse * 1.0;
  colour = colour * lighting + specular;
  colour = pow(colour, vec3(1.0 / 2.2));

  vec3 skyColor = mix(linearTosRGB(BEIGE), linearTosRGB(PINK), smoothstep(0.0, 0.35, vUvs.y));
  skyColor = mix(skyColor, linearTosRGB(BLUE), smoothstep(0.60, 1.0, vUvs.y));
  colour = mix(colour, skyColor, smoothstep(0.0, 1.0, d));
  gl_FragColor = vec4(colour, 1.0);
}