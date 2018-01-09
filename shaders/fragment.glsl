// Colour mode
const int RGB = 0;
const int GRY = 1;
const int BW  = 2;

// Textures
uniform sampler2D tCur_RGB;
uniform sampler2D tCur_NST;
uniform sampler2D tNxt_RGB;
uniform sampler2D tNxt_NST;
uniform sampler2D tSnw;
uniform sampler2D tWnm;
uniform sampler2D tGrs;

uniform bool bWtr;
uniform bool bSnw;
uniform bool bVeg;
uniform bool bPly;
uniform int eClr;
uniform int iCfd;
uniform int iCtr;
uniform int iYmx;
uniform float fTme;

varying vec2 vUv;
varying vec3 vViewPosition;
varying vec3 vVertexPosition;

// Interpolates two RGB colours
vec3 ClrInterp(vec3 clr_a, vec3 clr_b)
{
    float weight = fTme / 5.0;
    float r = (clr_a.r * (1.0 - weight)) + (clr_b.r * weight);
    float g = (clr_a.g * (1.0 - weight)) + (clr_b.g * weight);
    float b = (clr_a.b * (1.0 - weight)) + (clr_b.b * weight);
    return vec3(r,g,b);
}

void main()
{
    vec4 colour;
    vec2 ns;

    // If Animation is playing
    if(bPly)
    {
        // Interpolate RGB values
        vec3 ca = texture2D(tCur_RGB, vUv).rgb;
        vec3 cb = texture2D(tNxt_RGB, vUv).rgb;
        colour = vec4(ClrInterp(ca, cb), 1.0);

        // Interpolate Thermal values
        vec3 nsa = texture2D(tCur_NST, vUv).rgb;
        vec3 nsb = texture2D(tNxt_NST, vUv).rgb;
        ns = ClrInterp(nsa, nsb).rg;
    }
    else
    {
        colour = texture2D(tCur_RGB, vUv);
        ns = texture2D(tCur_NST, vUv).rg;
    }
    
    if(colour.rgb == vec3(0.0, 0.0, 0.0)){discard;}
    colour.b *= 0.666666667; // Scaling factor to offset bluish atmospheric hue
    
    // http://alteredqualia.com/three/examples/webgl_cubes_indexed.html
    // vec3 normal = normalize(cross(dFdx(vViewPosition), dFdy(vViewPosition)));
    
    float nir = ns.r;  // Near Infrared (NIR)
    float swir = ns.g; // Short Wave Infrared (SWIR)
    bool bRS = false;  // Flag to skip Rendering Scheme: RGB, Greyscale, or Black
    
    if(bWtr)
    {
        // S. Mcfeeters. The Use of Normalized Difference Water Index (NDWI) in the Delineation of Open Water Features.
        // Normalized Difference Water Index
        float NDWI = (float(colour.g) - float(nir)) / (float(colour.g) + float(nir));
        if(NDWI >= 0.15 + (float(iCfd) * 0.05))
        {
            bRS = true;
            // colour.rgb = vec3(NDWI);
            // vec3 e = normalize((viewMatrix * vec4(vVertexPosition.rg , 1.0, 1.0)).rgb - vVertexPosition);
            // colour.rgb *= dot(cameraPosition * texture2D(tWnm, vUv).rgb, e);
        }
    }

    if(!bRS && bSnw)
    {
        // J. Dozier. Spectral Signature of Alpine Snow Cover From Landsat Thematic Mapper.
        // Normalized Difference Snow Index
        float NDSI = (float(colour.g) - float(swir)) / (float(colour.g) + float(swir));
        if(NDSI >= 0.0 + (float(iCfd) * 0.175))
        {
            bRS = true;
            colour.rgb += texture2D(tSnw, vUv).rgb;
            colour.rgb /= 2.0;
        }
    }

    if(!bRS && bVeg)
    {
        // Kriegler et al. Preprocessing Transformations And Their Effects On Multispectral Recognition.
        // Normalized Difference Vegetation Index
        float NDVI = (float(nir) - float(colour.r)) / (float(nir) + float(colour.r));
        if(NDVI >= 0.70 + (float(iCfd) * 0.05))
        {
            bRS = true;
            colour.rgb = (colour.rgb * NDVI) + (texture2D(tGrs, vUv).rgb * (1.0 - NDVI));
        }
    }

    // Draw Rendering Scheme
    if(!bRS)
    {
        // Greyscale = (0.3 * r) + (0.59 * g) + (0.11 * b)
        if(eClr == GRY)
        {
            float gry = dot(colour.rgb, vec3(0.3, 0.59, 0.11));
            colour.rgb = vec3(gry, gry, gry);
        }
        // Black = (0, 0, 0)
        else if(eClr == BW)
        {
            colour.rgb = vec3(0.0);
        }
    }
    
    gl_FragColor = vec4(colour.rgb, 1.0);
}