// Colour mode
const int RGB = 0;
const int GRY = 1;
const int BW  = 2;

// Textures
uniform sampler2D tAug_1990_RGB;
uniform sampler2D tAug_1990_NST;
uniform sampler2D tAug_1994_RGB;
uniform sampler2D tAug_1994_NST;
uniform sampler2D tAug_1996_RGB;
uniform sampler2D tAug_1996_NST;
uniform sampler2D tAug_1997_RGB;
uniform sampler2D tAug_1997_NST;
uniform sampler2D tAug_1998_RGB;
uniform sampler2D tAug_1998_NST;
uniform sampler2D tAug_2002_RGB;
uniform sampler2D tAug_2002_NST;
uniform sampler2D tAug_2004_RGB;
uniform sampler2D tAug_2004_NST;
uniform sampler2D tAug_2006_RGB;
uniform sampler2D tAug_2006_NST;
uniform sampler2D tAug_2007_RGB;
uniform sampler2D tAug_2007_NST;
uniform sampler2D tAug_2009_RGB;
uniform sampler2D tAug_2009_NST;
uniform sampler2D tAug_2010_RGB;
uniform sampler2D tAug_2010_NST;
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

// Helper function for determining current RGB texture
vec3 GetColour(int ctr, vec2 uv)
{
    if(ctr == 0){return texture2D(tAug_1990_RGB, uv).rgb;}
    else if(ctr == 1){return texture2D(tAug_1994_RGB, uv).rgb;}
    else if(ctr == 2){return texture2D(tAug_1996_RGB, uv).rgb;}
    else if(ctr == 3){return texture2D(tAug_1997_RGB, uv).rgb;}        
    else if(ctr == 4){return texture2D(tAug_1998_RGB, uv).rgb;}
    else if(ctr == 5){return texture2D(tAug_2002_RGB, uv).rgb;}
    else if(ctr == 6){return texture2D(tAug_2004_RGB, uv).rgb;}
    else if(ctr == 7){return texture2D(tAug_2006_RGB, uv).rgb;}
    else if(ctr == 8){return texture2D(tAug_2007_RGB, uv).rgb;}
    else if(ctr == 9){return texture2D(tAug_2009_RGB, uv).rgb;}
    else if(ctr == 10){return texture2D(tAug_2010_RGB, uv).rgb;}
}

// Helper function for determining current thermal texture
vec3 GetThermals(int ctr, vec2 uv)
{
    if(ctr == 0){return texture2D(tAug_1990_NST, uv).rgb;}
    else if(ctr == 1){return texture2D(tAug_1994_NST, uv).rgb;}
    else if(ctr == 2){return texture2D(tAug_1996_NST, uv).rgb;}
    else if(ctr == 3){return texture2D(tAug_1997_NST, uv).rgb;}
    else if(ctr == 4){return texture2D(tAug_1998_NST, uv).rgb;}
    else if(ctr == 5){return texture2D(tAug_2002_NST, uv).rgb;}
    else if(ctr == 6){return texture2D(tAug_2004_NST, uv).rgb;}
    else if(ctr == 7){return texture2D(tAug_2006_NST, uv).rgb;}
    else if(ctr == 8){return texture2D(tAug_2007_NST, uv).rgb;}
    else if(ctr == 9){return texture2D(tAug_2009_NST, uv).rgb;}
    else if(ctr == 10){return texture2D(tAug_2010_NST, uv).rgb;}
}

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
        int next_texture = (iCtr == 10) ? 0 : iCtr + 1;
        vec3 ca = GetColour(iCtr, vUv);
        vec3 cb = GetColour(next_texture, vUv);
        colour = vec4(ClrInterp(ca, cb), 1.0);

        // Interpolate Thermal values
        vec3 nsa = GetThermals(iCtr, vUv);
        vec3 nsb = GetThermals(next_texture, vUv);
        ns = ClrInterp(nsa, nsb).rg;
    }
    else
    {
        colour = vec4(GetColour(iCtr, vUv), 1.0);
        ns = GetThermals(iCtr, vUv).rg;
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