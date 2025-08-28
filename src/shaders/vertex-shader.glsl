varying vec2 vUvs;
varying vec3 vNormal;

void main() {	
  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  vUvs = uv;
  vNormal = (modelMatrix * vec4(normal, 0.0)).xyz;
}