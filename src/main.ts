import * as THREE from 'three';
import fragmentShader from './shaders/fragment-shader.glsl'
import vertexShader from './shaders/vertex-shader.glsl'

class ThreeApp {
  threejs_: THREE.WebGLRenderer;
  scene_: THREE.Scene;
  camera_: THREE.OrthographicCamera;
  previousRAF_: number | null = null;
  material_: THREE.ShaderMaterial | null = null;
  totalTime_: number = 0;
  trailLength: number;
  pointerTrail: THREE.Vector2[];
  pointer: THREE.Vector2;
  constructor() {
    this.threejs_ = new THREE.WebGLRenderer();
    document.body.appendChild(this.threejs_.domElement);

    window.addEventListener('resize', () => {
      this.onWindowResize_();
    }, false);
    window.addEventListener('pointermove',(e)=>this.onMouseMove_(e))
    this.scene_ = new THREE.Scene();

    this.camera_ = new THREE.OrthographicCamera(0, 1, 1, 0, 0.1, 1000);
    this.camera_.position.set(0, 0, 1);
    this.trailLength = 20;
    this.pointerTrail = Array.from({ length: this.trailLength }, () => new THREE.Vector2(0, 0));
    this.pointer = new THREE.Vector2(0,0);
  }

   initialize() {
   

    this.setupProject_();
    this.previousRAF_ = null;
    this.onWindowResize_();
    this.raf_();
  }

   setupProject_() {
    const material = new THREE.ShaderMaterial({
      uniforms: {
        resolution: { value: new THREE.Vector2(window.innerWidth, window.innerHeight) },
        time: { value: 0.0 },
        uMousePos: {value: new THREE.Vector2(0,0)},
        uPointerTrail: { value: this.pointerTrail },
      },
      vertexShader: vertexShader,
      fragmentShader: fragmentShader
    });

    this.material_ = material;

    const geometry = new THREE.PlaneGeometry(1, 1);
    const plane = new THREE.Mesh(geometry, material);
    plane.position.set(0.5, 0.5, 0);
    this.scene_.add(plane);
    
    this.totalTime_ = 0;
    this.onWindowResize_();
  }
  updatePointerTrail() {
    for (let i = this.trailLength - 1; i > 0; i--) {
       this.pointerTrail[i].copy(this.pointerTrail[i - 1]);
    }
    this.pointerTrail[0].copy(this.pointer);
  }
  onWindowResize_() {
    const dpr = window.devicePixelRatio;
    const canvas = this.threejs_.domElement;
    canvas.style.width = window.innerWidth + 'px';
    canvas.style.height = window.innerHeight + 'px';
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;

    this.threejs_.setSize(w * dpr, h * dpr, false);
    if (this.material_) {
        this.material_.uniforms.resolution.value = new THREE.Vector2(
            window.innerWidth * dpr, window.innerHeight * dpr);
    }
  }
  onMouseMove_(e: MouseEvent){
    this.pointer.x = e.x - (window.innerWidth / 2);
    this.pointer.y = e.y - (window.innerHeight / 2);
    if (this.material_) {
      this.material_.uniforms.uMousePos.value = new THREE.Vector2(this.pointer.x, - this.pointer.y)
  }
  }
  raf_() {
    requestAnimationFrame((t) => {
      if (this.previousRAF_ === null) {
        this.previousRAF_ = t;
      }

      this.step_(t - this.previousRAF_);
      this.threejs_.render(this.scene_, this.camera_);
      this.raf_();
      this.previousRAF_ = t;
    });
    this.updatePointerTrail();
  }

  step_(timeElapsed: number) {
    const timeElapsedS = timeElapsed * 0.001;
    this.totalTime_ += timeElapsedS;

    if (this.material_) {
        this.material_.uniforms.time.value = this.totalTime_;
    }
  }
}


let APP_ = null;

window.addEventListener('DOMContentLoaded', async () => {
  APP_ = new ThreeApp();
  APP_.initialize();
});
