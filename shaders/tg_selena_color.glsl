#include "tg_common.glh" 

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

vec4  ColorMapSelena(vec3 point, float height, float slope, vec3 norm, in BiomeData biomeData)
{
    Surface surf;

    // Assign a climate type
	noiseOctaves    = 4.0; // Reduced for smoother transitions
	noiseH          = 0.4; // Lower roughness for subtler variations
	noiseLacunarity = 2.0; // Adjusted for more natural-looking patterns
	noiseOffset     = 0.7; // Lower offset for less pronounced variations
	float climate, latitude, lat, dist;

// Biome domains
	vec3  p = point * mainFreq + Randomize;
	vec4  col;
	noiseOctaves = 4;
	vec3  distort = p * 2.0 + 10.0 * Fbm3D(p * 0.05); // Adjusted for smoother biome transitions
	vec2  cell = Cell3Noise2Color(distort, col);
	float biome = col.r;
	float biomeScale = saturate(1.5 * (pow(abs(cell.y - cell.x), 0.6) - 0.1)); // Adjusted for more gradual color changes

    // Assign a material
    noiseOctaves = 12.0;

    if (tidalLock <= 0.0)
    {
        lat = abs(point.y);
        latitude = lat + 0.15 * (Fbm(point * 0.7 + Randomize) - 1.0);
        latitude = saturate(latitude);
        climate = biomeData.height;
    }
    else
    {
        lat = 1.0 - point.x;
        latitude = lat + 0.15 * (Fbm(point * 0.7 + Randomize) - 1.0);
        climate = mix(climateTropic, climatePole, saturate(latitude));
    }

    // Color texture distortion
	noiseOctaves = 8.0; // Reduced octaves for a smoother texture
	dist = 1.0 * floor(1.5 * DistFbm(point * 0.0015 * colorDistFreq, 1.5));
	climate += colorDistMagn * dist;

	// Color texture variation
	noiseOctaves = 4;
	p = point * colorDistFreq * 1.5;
	p += Fbm3D(p * 0.4) * 0.9;
	float vary = saturate((Fbm(p) + 0.6) * 0.5);

    // Shield volcano lava
    if (volcanoOctaves > 0)
    {
        // Global volcano activity mask
        noiseOctaves = 3;
        float volcActivity = saturate((Fbm(point * 1.37 + Randomize) - 1.0 + volcanoActivity) * 5.0);
        // Lava in volcano caldera and flows
	    vec2  volcMask = VolcanoGlowNoise(point);
        volcMask.x *= volcActivity;
		// Model lava as rocks texture
		climate = mix(climate, 0.0, volcMask.x);
		biomeData.slope = mix(biomeData.slope, 0.0, volcMask.x);
    }

    // Surface surf = GetSurfaceColor(saturate(climate), biomeData.slope, vary);

    // Scale detail texture UV and add a small distortion to it to fix pixelization
    vec2 detUV = (TexCoord.xy * faceParams.z + faceParams.xy) * texScale;
    noiseOctaves = 4.0;
    vec2 shatterUV = Fbm2D2(detUV * 16.0) * (16.0 / 512.0);
    detUV += shatterUV;

    surf = GetBaseSurface(biomeData.height, detUV);

    // Global albedo variations
	vec3 zz = (point + Randomize) * (0.0004 * hillsFreq / (hillsMagn * hillsMagn));
	noiseOctaves = 8.0; // Reduced octaves for smoother variations
	vec3 albedoVaryDistort = Fbm3D((point + Randomize) * 0.05) * (1.0 + venusMagn);

	vary = 1.0 - Fbm((point + albedoVaryDistort) * (1.0 - RidgedMultifractal(zz, 6.0) + RidgedMultifractal(zz * 0.999, 6.0)));

	vary *= 0.3 * vary * vary; // Reduced scaling for less prominent variations
	noiseOctaves = 6;
	distort = Fbm3D((point + Randomize) * 0.05) * 1.0; // Smoother distortion
	noiseOctaves = 4;
	float slopeMod = 1.0 - biomeData.slope;
	vary = saturate(1.0 - Fbm((point + distort) * 0.6) * slopeMod * slopeMod * 1.5); // Adjusted for subtler albedo changes
	
    if (craterSqrtDensity > 0.05)
    {
        // Young terrain - suppress craters
        noiseOctaves = 4.0;
        vec3 youngDistort = Fbm3D((point - Randomize) * 0.07) * 1.1;
        noiseOctaves = 8.0;
        float young = 1.0 - Fbm(point + youngDistort);
        young = smoothstep(0.0, 1.0, young * young * young);
        vary = mix(0.0, vary, young);
    }
	

// Rayed craters
    if (craterSqrtDensity * craterSqrtDensity * craterRayedFactor > 0.05 * 0.05)
    {
        float craterRayedSqrtDensity = craterSqrtDensity * sqrt(craterRayedFactor);
        float craterRayedOctaves = floor(craterOctaves * craterRayedFactor);
        float crater = RayedCraterColorNoise(point, craterFreq, craterRayedSqrtDensity, craterRayedOctaves);
        surf.color.rgb = mix(surf.color.rgb, vec3(1.0), crater);
	}

    // Ice cracks
    float mask = 1.0;
    if (cracksOctaves > 0.0)
        vary *= CrackColorNoise(point, mask);

// Apply albedo variations
    // Reduced influence of 'vary' for less prominent albedo variations
	float albedoFactor = 0.333; // Lower this value for subtler variations

	surf.color *= mix(vec4(0.60, 0.59, 0.58, 0.00), vec4(1.0), vary * albedoFactor);
	surf.color.rgb *= mix(colorVary, vec3(1.0), vary * albedoFactor);
	
	// Apply gamma correction to increase brightness
	float gamma = 1.5; // Lower than 1.0 to brighten, higher to darken
	surf.color.rgb = pow(surf.color.rgb, vec3(1.0 / gamma));
	
//PLUTO-LIKE TERRAIN
	if ((cracksOctaves > 0.0) && (mareFreq > 1.7))
	{
		float basins = 1;
		basins *= 1.0 - smoothstep(0.3, 0.02, biomeData.height- seaLevel );
		surf.color.rgb *= mix(colorVary, vec3(1.0), basins);
	}

//ENCELADUS TYPE TERRAINS
	if ((cracksOctaves > 0.0) && (canyonsMagn > 0.52) && (mareFreq < 1.7))
	{
		if (cracksFreq <0.6)
		{
			vary /= CrackColorNoise(point, mask);
			noiseOctaves     = 6.0;
            noiseLacunarity  = 2.218281828459;
            noiseH           = 0.9;
            noiseOffset      = 0.5;
            p = point * 0.5* mainFreq + Randomize;
			distort = Fbm3D(point * 0.1) * 3.5+Fbm3D(point * 0.1) * 6.5+ Fbm3D(point * 0.1) * 12.5;
            cell = Cell3Noise2(canyonsFreq * 0.05 * p + distort);
            float rima2 = 2- saturate(abs(cell.y - cell.x) * 250.0 * canyonsMagn);
            rima2 = biomeScale * smoothstep(0.0, 1.0, rima2);
			
			noiseOctaves = 1;
			distort = Fbm3D(point * 0.1) * 3.5;
			float venus2 = (Fbm(point + distort)*1.5)*0.5;
            
			vary -= 1- rima2;
			// surf.color = mix(vec4(0.75, 0.9, 1.0, 0.00), vec4(1.0), vary * venus2);
			surf.color.rgb = mix(colorVary, vec3(1.0), vary * venus2);
		}
	}

    // EUROPA-TYPE TERRAIN
    if ((cracksOctaves > 0.0) && (canyonsMagn > 0.5) && (mareFreq < 1.7))
	{
		noiseOctaves = 5.0;
		noiseH       = 0.9;
		noiseLacunarity = 4.0;
		noiseOffset  = 1/(montesSpiky);
		p = 0.7 *point * mainFreq + Randomize;
		distort  = 0.035 * Fbm3D(p * riversSin * 4);
		distort += 0.050 * Fbm3D(p * riversSin);

		cell =  Cell3Noise2(riversFreq * (p * p)  + distort);
		float c = abs(cell.y - cell.x) * riversMagn;

		float x = smoothstep (0.0, 0.7, 1.0 - saturate ( 2.0 * c));

		p *= 1.5;
		cell =  Cell3Noise2(riversFreq * (p * p)   + 2*distort);
		c = abs(cell.y - cell.x) * riversMagn;       
		float y = smoothstep (0.0, 0.6, 1.0 - saturate ( 2.0 * c));

		p *= 2;
		cell =  Cell3Noise2(riversFreq * (p * p)   + 4*distort);
		c = abs(cell.y - cell.x) * riversMagn;       

		float z = smoothstep (0.0, 0.6, 1.0 - saturate ( 2.0 * c));

		p *= 0.5*p;
		cell =  Cell3Noise2(riversFreq * (p * p)   + 8*distort);
		c = abs(cell.y - cell.x) * riversMagn;       

		float k = smoothstep (0.0, 2.0, 1.0 - saturate ( 2.0 * c));

		float crack = 1.0-(x+y+z+k);

		vary *= crack;
		
		surf.color.rgb *= mix(colorVary, vec3(1.0), vary); 
	}
	
	else
	{
		float global = 1.0; // - Cell3Noise(p + distort);
		
		noiseOctaves = 8.0;
		float fr = 0.20 * (1.5 - RidgedMultifractal(zz, 2.0)) + 0.05 * (1.5 - RidgedMultifractal(zz * 10.0,  2.0));
			zz *= 1 - smoothstep(-0.01, 0.02, biomeData.height - seaLevel);
			
		noiseOctaves = 8.0;
		float zr = 1.0 - Fbm((point + distort) * 0.78)+0.20 * (1.5 - RidgedMultifractal(zz, 2.0)) + 0.05 * (1.5 - RidgedMultifractalDetail(zz * 10.0,  2.0, 0.5*biomeScale)) + 0.04 * (1.5 - RidgedMultifractal(zz * 100.0, 4.0));
		zr = smoothstep(0.0, 1.0, 0.2*zr*zr);
		zr *= 1 - smoothstep(0.0, 0.02, biomeData.height - seaLevel);
		zr = 0.1*hillsFreq* smoothstep(0.0, 1.0, zr);
		global =  mix(global,global+0.0006,zr);
		
        float rr  = 0.3*((0.15 * iqTurbulence(point * 0.4 * montesFreq +Randomize, 0.45)) * (RidgedMultifractalDetail(point * point * montesFreq *0.8 + Randomize, 1.0, biomeScale)));
		rr *= 1 - smoothstep(0.0, 0.02, biomeData.height - seaLevel);
		global += rr;
		
		global = 0.9 * global + 0.06 * (fr * zr * rr);
		
		surf.color.rgb *= mix(colorVary, vec3(1.0), global); 
	}
	
	/*
	if ((cracksOctaves > 0.0) && (canyonsMagn < 0.6) && (mareFreq < 1.7))
	{
		float crater *=0.5;
	}
	*/
    // "Freckles" (structures like on Europa)
    if ((biome > hillsFraction) && (biome < hills2Fraction))
    {
        noiseOctaves    = 10.0;
        noiseLacunarity = 2.0;
        vary *= 1.0 - saturate(2.0 * mask * biomeScale * JordanTurbulence(point * hillsFreq + Randomize, 0.8, 0.5, 0.6, 0.35, 1.0, 0.8, 1.0));
    }

    // Vegetation
    if (plantsBiomeOffset > 0.0)
    {
        noiseH          = 0.5;
        noiseLacunarity = 2.218281828459;
        noiseOffset     = 0.8;
        noiseOctaves    = 2.0;
        float plantsTransFractal = abs(0.125 * Fbm(point * 3.0e5) + 0.125 * Fbm(point * 1.0e3));

        // Modulate by humidity
        noiseOctaves = 8.0;
        float humidityMod = Fbm((point + albedoVaryDistort) * 1.73) - 1.0 + humidity * 2.0;

        float plantsFade = smoothstep(beachWidth, beachWidth * 2.0, biomeData.height - seaLevel) *
                           smoothstep(0.750, 0.650, biomeData.slope) *
                           smoothstep(-0.5, 0.5, humidityMod);

        // Interpolate previous surface to the vegetation surface
        ModifySurfaceByPlants(surf, detUV, climate, plantsFade, plantsTransFractal);
    }

    // Make driven hemisphere darker
    if (drivenDarkening != 0.0)
    {
        noiseOctaves = 3;
        float z = -point.z * sign(drivenDarkening);
        z += 0.2 * Fbm(point * 1.63);
        z = saturate(1.0 - z);
        z *= z;
        surf.color.rgb *= mix(1.0 - abs(drivenDarkening), 1.0, z);
    }

    // Ice caps - thin frost
    // TODO: make it only on shadowed slopes
    float iceCap = saturate((latitude - latIceCaps) * 2.0);
    surf.color.rgb = mix(surf.color.rgb, vec3(1.0), 0.4 * iceCap);

    return surf.color;
}

//-----------------------------------------------------------------------------

void main()
{
    vec3  point = GetSurfacePoint();
    float height, slope;
    vec3  norm;
    BiomeData biomeData = GetSurfaceBiomeData();
    GetSurfaceHeightAndSlopeAndNormal(height, slope, norm);
    OutColor = ColorMapSelena(point, height, slope, norm, biomeData);
    OutColor.rgb = pow(OutColor.rgb, colorGamma);
}

//-----------------------------------------------------------------------------

#endif
