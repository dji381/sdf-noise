varying vec2 vUvs;
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
float opUnion(float d1, float d2) {
  return min(d1, d2);
}

float opSubtraction(float d1, float d2) {
  return max(-d1, d2);
}

float opIntersection(float d1, float d2) {
  return max(d1, d2);
}
float softMax(float a, float b, float k) {
  return log(exp(k * a) + exp(k * b)) / k;
}

float softMin(float a, float b, float k) {
  return -softMax(-a, -b, k);
}

float softMinValue(float a, float b, float k) {
  float h = exp(-b * k) / (exp(-a * k) + exp(-b * k));
  // float h = remap(a - b, -1.0 / k, 1.0 / k, 0.0, 1.0);
  return h;
}
vec2 random(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    float a = random(i).x;
    float b = random(i + vec2(1.0, 0.0)).x;
    float c = random(i + vec2(0.0, 1.0)).x;
    float d = random(i + vec2(1.0, 1.0)).x;
    
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    int octaves = 6;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}
void main() {
  vec2 offsetUvs = (vUvs - 0.5);
  vec2 pixelCoords =  offsetUvs * resolution;
  vec2 pos = pixelCoords;
  pos -= uMousePos;
  float d1 = sdfCircle(pos,150.0);
  float d2 = sdfCircle(pixelCoords,150.0);
  vec3 colour = vec3(0.0);

  // Paramètres pour contrôler l'aspect du bruit
  float frequency = 0.005; // Zoom sur le bruit. Plus c'est petit, plus les vagues sont grandes.
  float amplitude = 30.0;  // Force de la distorsion en pixels.
  
  // On calcule une valeur de bruit qui dépend de la position et du temps.
  // L'ajout de 'time' est ce qui crée l'animation !
  float distortion = sin(fbm(pixelCoords * frequency + time * 0.2) * amplitude);
  distortion = remap(distortion,-1.0,1.0,0.0,1.0);
  // Couleurs du dégradé
  vec3 colorA = vec3(0.1, 0.5, 0.9);
  vec3 colorB = vec3(0.9, 0.2, 0.5); 
  vec3 gradientColor = mix(colorA, colorB, vUvs.y);
  vec3 noiseColor = mix(gradientColor,vec3(distortion),vUvs.x);
  float d = softMin(d1,d2,0.05);
  colour = mix(noiseColor,colour, smoothstep(0.0,1.0,d));
  gl_FragColor = vec4(colour, 1.0);
}