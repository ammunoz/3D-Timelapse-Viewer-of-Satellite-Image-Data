// Initialize
var scene     = new THREE.Scene();
var aspect    = window.innerWidth / window.innerHeight;
var camera    = new THREE.PerspectiveCamera( 75, aspect, 10, 2500 );
var renderer  = new THREE.WebGLRenderer( {alpha: true, antialias: true} );
var controls  = new THREE.OrbitControls( camera, renderer.domElement );
var keyboard  = new THREEx.KeyboardState();
var clock     = new THREE.Clock();
var was_pressed = {};

// Prepare Renderer
renderer.setSize( window.innerWidth, window.innerHeight );
document.body.appendChild( renderer.domElement );
scene.background = new THREE.Color( 0xdbf2f5 );
camera.position.y = 100; camera.position.z = 350;

// Control configs
controls.dollyIn = function(){this.object.position.z += 100;}
controls.dollyOut = function(){this.object.position.z -= 100;}

// Texturing 8121 x 7341
var textureloader = new THREE.TextureLoader();
var map_dem = textureloader.load("data/PNG/ASTER_DEM.png");
map_dem.minFilter = THREE.LinearFilter;
var map_snw = textureloader.load("data/JPG/snow.jpg");
map_snw.minFilter = THREE.LinearFilter;
var map_wht = textureloader.load("data/PNG/waterheight.png");
map_wht.minFilter = THREE.LinearFilter; map_wht.wrapT = map_wht.wrapS = THREE.RepeatWrapping;
var map_wnm = textureloader.load("data/PNG/waternormal.png");
map_wnm.minFilter = THREE.LinearFilter; map_wnm.wrapT = map_wnm.wrapS = THREE.RepeatWrapping;
var map_grs = textureloader.load("data/JPG/grasslight-big.jpg");
map_grs.minFilter = THREE.LinearFilter; map_grs.wrapT = map_grs.wrapS = THREE.RepeatWrapping;

// Add Skydome to scene
/*
var map_sky = textureloader.load("data/JPG/sky.jpg");
map_sky.minFilter = THREE.LinearFilter; map_sky.wrapT = map_sky.wrapS = THREE.RepeatWrapping;
var skydome_geometry = new THREE.SphereGeometry( 2000, 60, 40 );
var skydome_material = new THREE.MeshBasicMaterial({ map: map_sky, side: THREE.BackSide });
var skydome = new THREE.Mesh(skydome_geometry, skydome_material);
skydome.rotateY(- Math.PI / 2.0);
scene.add(skydome);
*/

// Prepare Shader uniforms
var uniforms =
{
  // Textures
  tDem: {type: "t", value: map_dem}, // DEM texture
  tSnw: {type: "t", value: map_snw}, // Snow texture
  tWht: {type: "t", value: map_wht}, // Water height texture
  tWnm: {type: "t", value: map_wnm}, // Water normal texture
  tGrs: {type: "t", value: map_grs}, // Grass texture

  // Shader Params
  bWtr: {type: "b", value: false}, // Display NDWI
  bSnw: {type: "b", value: false}, // Display NDSI
  bVeg: {type: "b", value: false}, // Display NDVI
  bPly: {type: "b", value: false}, // Play Animation
  eClr: {type: "i", value: 0}, // Rendering colour mode
  iCfd: {type: "i", value: 0}, // Confidence interval
  iCtr: {type: "i", value: 0}, // Texture counter
  iYmx: {type: "i", value: 0}, // Year max
  fTme: {type: "f", value: 0}  // Time
};

// Load textures and prepare to send to GPU
var map_aug ={};
const keys = ["RGB", "NST"];
const years = [1990, 1994, 1996, 1997, 1998, 2002, 2004, 2006, 2007, 2009, 2010];
for(var year = 0; year < years.length; ++year)
{
  for(var key = 0; key < keys.length; ++key)
  {
    map_aug[years[year]] = {};
    map_aug[years[year]][keys[key]] = textureloader.load("data/PNG/August-Downsized/AUG_" + years[year] + "_" + keys[key] + ".PNG");
    map_aug[years[year]][keys[key]].minFilter = THREE.LinearFilter;
    uniforms["tAug_" + years[year] + "_" + keys[key]] =
    {
      type: "t",
      value: map_aug[years[year]][keys[key]]
    };
  }
}
uniforms.iYmx.value = years.length - 1;
var textbox = document.getElementById("textbox");
textbox.innerText = "LOADING..";

// GUI elements
var gui = new dat.GUI({height : 5 * 32 - 1});
var colour = gui.addFolder('Colour');
colour.add(uniforms["eClr"], 'value', {RGB: 0, GRY: 1, BW: 2}).name("Mode").listen();
var detection = gui.addFolder('Detection');
detection.add(uniforms["bWtr"], 'value').name("Detect Water").listen();
detection.add(uniforms["bSnw"], 'value').name("Detect Ice / Snow").listen();
detection.add(uniforms["bVeg"], 'value').name("Detect Vegetation").listen();
detection.add(uniforms["iCfd"], 'value', 0, 3).name("Confidence Interval").listen();
gui.add(uniforms["iCtr"], 'value', 0, years.length - 1).step(1).name("Year Index").listen();
gui.add(uniforms["bPly"], 'value').name("Play Animation").listen();

// Statistics
var stats_fps = new Stats();
stats_fps.showPanel(0); // Panel 0 = fps
stats_fps.domElement.style.cssText = 'position:absolute;bottom:0px;left:0px;';
document.body.appendChild(stats_fps.domElement);

var stats_ram = new Stats();
stats_ram.showPanel(2); // Panel 2 = MB
stats_ram.domElement.style.cssText = 'position:absolute;bottom:0px;left:80px;';
document.body.appendChild(stats_ram.domElement);

// Halt progress until shaders are loaded
ShaderLoader("shaders/vertex.glsl", "shaders/fragment.glsl", function(vertex, fragment)
{
  // Create plane geometry
  var geometry    = new THREE.PlaneGeometry( 1000, 913, 1000, 913 );
  var material    = new THREE.ShaderMaterial
  ({
    uniforms:       uniforms,
    vertexShader:   vertex,
    fragmentShader: fragment
  });
  geometry.verticesNeedUpdate = true;
  material.extensions.derivatives = true;
  var plane = new THREE.Mesh( geometry, material );
  plane.rotateX(- Math.PI / 2.0);
  scene.add( plane );
  
  // Show info
  document.getElementById("info").style.display = 'block';
  // Change textures every 5 seconds
  setInterval(play, 5000);
  render();

  function render()
  {
    // Capture keyboard input
    ReadKeyboard();
    // Calculate time offsets
    UpdateClock();
    // Capture camera controls
    controls.update();
    // Update statistics
    stats_fps.update();
    stats_ram.update();
    // Update textbox
    textbox.innerText = "August " + years[uniforms.iCtr.value];
    // Animate
    requestAnimationFrame( render );
    // Render scene
    renderer.render( scene, camera );
  };
});

function play()
{
  if(!uniforms.bPly.value) return;
  uniforms.iCtr.value = (uniforms.iCtr.value + 1) % years.length;
  uniforms.fTme.value = 0;
};

function UpdateClock()
{
  if(!uniforms.bPly.value) return;
  var delta = clock.getDelta();
  uniforms.fTme.value = uniforms.fTme.value + delta;
}

function ReadKeyboard()
{
  keyboard.domElement.addEventListener('keydown', function(event){
		if (event.repeat) {
			return;
    }
    
    if(keyboard.eventMatches(event, 'Q') && !was_pressed['Q'])
    {
      uniforms.eClr.value = 0;
      was_pressed['Q'] = true;
      console.log("eClr: RGB");
    }

    if(keyboard.eventMatches(event, 'W') && !was_pressed['W'])
    {
      uniforms.eClr.value = 1;
      was_pressed['W'] = true;
      console.log("eClr: GRY");
    }

    if(keyboard.eventMatches(event, 'A') && !was_pressed['A'])
    {
      uniforms.eClr.value = 2;
      was_pressed['A'] = true;
      console.log("eClr: BW");
    }
    
    if(keyboard.eventMatches(event, 'E') && !was_pressed['E'])
    {
      uniforms.bWtr.value ^= 1;
      was_pressed['E'] = true;
      console.log("bWtr: " + uniforms.bWtr.value);
    }

    if(keyboard.eventMatches(event, 'R') && !was_pressed['R'])
    {
      uniforms.bSnw.value ^= 1;
      was_pressed['R'] = true;
      console.log("bSnw: " + uniforms.bSnw.value);
    }

    if(keyboard.eventMatches(event, 'T') && !was_pressed['T'])
    {
      uniforms.bVeg.value ^= 1;
      was_pressed['T'] = true;
      console.log("bVeg: " + uniforms.bVeg.value);
    }

    
    if(keyboard.eventMatches(event, 'pageup') && !was_pressed['pageup'])
    {
      if(uniforms.iCfd.value < 2) ++uniforms.iCfd.value;
      was_pressed['pageup'] = true;
      console.log("iCfd: " + uniforms.iCfd.value);
    }

    if(keyboard.eventMatches(event, 'pagedown') && !was_pressed['pagedown'])
    {
      if(uniforms.iCfd.value > 0) --uniforms.iCfd.value;
      was_pressed['pagedown'] = true;
      console.log("iCfd: " + uniforms.iCfd.value);
    }

    if(keyboard.eventMatches(event, 'space') && !was_pressed['space'])
    {
      uniforms.bPly.value != uniforms.bPly.value;
      uniforms.fTme.value = 0.0;
      was_pressed['space'] = true;
      console.log("bPly: " + uniforms.bPly.value);
    }
  
  });
  
  keyboard.domElement.addEventListener('keyup', function(event){
    if (event.repeat) {
			return;
    }
    
    if(keyboard.eventMatches(event, 'Q') && was_pressed['Q'])
    {
      was_pressed['Q'] = false;
    }

    if(keyboard.eventMatches(event, 'W') && was_pressed['W'])
    {
      was_pressed['W'] = false;
    }

    if(keyboard.eventMatches(event, 'A') && was_pressed['A'])
    {
      was_pressed['A'] = false;
    }
    
    if(keyboard.eventMatches(event, 'E') && was_pressed['E'])
    {
      was_pressed['E'] = false;
    }

    if(keyboard.eventMatches(event, 'R') && was_pressed['R'])
    {
      was_pressed['R'] = false;
    }

    if(keyboard.eventMatches(event, 'T') && was_pressed['T'])
    {
      was_pressed['T'] = false;
    }

    
    if(keyboard.eventMatches(event, 'pageup') && was_pressed['pageup'])
    {
      was_pressed['pageup'] = false;
    }

    if(keyboard.eventMatches(event, 'pagedown') && was_pressed['pagedown'])
    {
      was_pressed['pagedown'] = false;
    }

    if(keyboard.eventMatches(event, 'space') && was_pressed['space'])
    {
      was_pressed['space'] = false;
    }

  });
}