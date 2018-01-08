varying vec2 vUv;
varying vec3 vViewPosition;
varying vec3 vVertexPosition;

uniform sampler2D tDem;
uniform sampler2D tWht;
uniform float fTme;

const float pi = 3.14159;

void main()
{
    vUv = uv;
    vVertexPosition = position;

    // Deterrmine elevation from DEM texture
    float scale = 50.0;
    float altitude = texture2D(tDem, vUv).b * scale;
    
    // Use DEM texture as height map
    vec4 mvPosition = modelViewMatrix * vec4(position.xy, altitude, 1.0);
    vViewPosition = -mvPosition.xyz;
    gl_Position = projectionMatrix * mvPosition;
}