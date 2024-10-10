#include "tg_common.glh" 

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------
// Modified Rodrigo's rifts

void    RmRifts(vec3 point, float damping, inout float height)
{
    float riftsBottom = seaLevel;

    noiseOctaves    = 6.6;
    noiseH          = 1.0;
    noiseLacunarity = 4.0;
    noiseOffset     = 0.95;

    // 2 slightly different octaves to make ridges inside rifts
    vec3 p = point * 0.12;
    float rifts = 0.0;
    for (int i=0; i<2; i++)
    {
        vec3  distort = 0.5 * Fbm3D(p * riftsSin)+ 0.1 * Fbm3D(p*3 * riftsSin);;
        vec2  cell = Cell3Noise2(riftsFreq * p + distort);
        float width = 0.8*riftsMagn * abs(cell.y - cell.x);
        rifts = softExpMaxMin(rifts, 1.0 - 2.75 * width, 32.0);
        p *= 1.02;
    }

    float riftsModulate = smoothstep(-0.1, 0.2, Fbm(point * 2.3 + Randomize));
    rifts = smoothstep(0.0,1.0, rifts * riftsModulate) * damping;

    height = mix(height, riftsBottom, rifts);

    // Slope modulation
    if (rifts > 0.0)
    {
        float slope = smoothstep(0.1, 0.9, 1.0 - 2.0 * abs(rifts * 0.35 - 0.5));
        float slopeMod = 0.5*slope * RidgedMultifractalErodedDetail(point * 5.0 * canyonsFreq + Randomize, 8.0, erosion, 8.0);
        slopeMod *= 0.05*riftsModulate;
        height = softExpMaxMin(height - slopeMod, riftsBottom, 32.0);
    }
}

//-----------------------------------------------------------------------------

float   HeightMapSelena(vec3 point)
{
    // Biome domains
    vec3  p = point * mainFreq + Randomize;
    vec4  col;
    noiseOctaves = 6;
    vec3  distort = p * 2.3 + 13.5 * Fbm3D(p * 0.06);
    vec2  cell = Cell3Noise2Color(distort, col);
    float biome = col.r;
    float biomeScale = saturate(2.0 * (pow(abs(cell.y - cell.x), 0.7) - 0.05));

    float montRange = saturate(DistNoise(point * 22.6 + Randomize, 2.5) + 0.5);
    montRange *= montRange;
    float montBiomeScale = min(pow(2.2 * biomeScale, 2.5), 1.0) * montRange;
    float inv2montesSpiky = 1.0 /(montesSpiky*montesSpiky);
	float mask = 1.0;
	float height = 0.0;


    // Global landscape
	noiseOctaves = 6; // Increase the number of octaves for more detailed noise
    p = point * mainFreq + Randomize;
	distort = 0.45 * Fbm3D(p * 0.73); // Increase the distortion for more rugged terrain
    p += distort + 0.005 * (1.0 - abs(Fbm3D(p * 132.3)));
	noiseOctaves = 12.0; // Increase the number of octaves for more detailed noise
		noiseH = 1.0;
		noiseLacunarity = 2.5; // Increase the lacunarity for more complex noise
		noiseOffset = montesSpiky;
	float rocks = iqTurbulence(point * 100 , 1); // Increase the frequency for more detailed rock formations

	noiseOctaves = 5; // Increase the number of octaves for more detailed noise
	distort += 0.01 * (1.0 - abs(Fbm3D(p * 132.3))); // Increase the distortion for more rugged terrain
	vec3 pp = (point + Randomize) * (0.001 * hillsFreq / (hillsMagn * hillsMagn)); // Increase the frequency for more detailed terrain
	float fr = 0.25 * (1.5 - RidgedMultifractal(pp, 2.0)); // Increase the fractal range for more varied terrain
	// float global = 1 - Cell3Noise(p + distort);  // This causes Selenas and IceWorlds to puff up!
	float global = 0.6 * (1.0 - Cell3Noise(p));
	fr *= 1.0 - smoothstep(0.02, 0.01, global - seaLevel); // Decrease the smoothstep threshold for more rugged terrain

    // Venus-like structure
    float venus = 0.0;
    if (venusMagn > 0.05)
	{
        noiseOctaves = 4;
        distort = Fbm3D(point * 0.3) * 1.5;
        noiseOctaves = 6;
        venus = Fbm((point + distort) * venusFreq + 0.1) * (venusMagn + 0.1);
    }
		noiseOctaves = 8;
		
		global += venus;
		// global = (global + 0.8 *venus+ (0.000006 * (hillsFreq + 1500)) * fr - seaLevel)* 0.5 + seaLevel;
		
		float mr = 1.0 + 2*Fbm(point + distort) + 7 * (1.5 - RidgedMultifractalEroded(pp *0.8, 8.0, erosion)) - 6 * (1.5 - RidgedMultifractalEroded(pp * 0.1,  8.0,erosion));
		mr = smoothstep(0.0, 1.0, 0.2*mr*mr);
		mr *= 1 - smoothstep(-0.01, 0.00, seaLevel-global);
		mr = 0.1*hillsFreq* smoothstep(0.0, 1.0, mr);
		global =  mix(global,global+0.0003,mr);

    // Mare
    float mare = global;
    float mareFloor = global;
    float mareSuppress = 1.0;
    if (mareSqrtDensity > 0.05)
    {
        noiseOctaves = 2;
        mareFloor = 0.6 * (1.0 - Cell3Noise(0.3*p));
        craterDistortion = 1.0;
        noiseOctaves = 6;  // Mare roundness distortion
        mare = MareNoise(point, global, mareFloor, mareSuppress);
    }

    // Old craters
    float crater = 0.0;
    if (craterSqrtDensity > 0.05)
    {
        heightFloor = -0.2; // Lower the floor of the craters for more depth
		heightPeak  =  0.7; // Increase the peak height for more pronounced craters
		heightRim   =  1.2; // Increase the rim height for more pronounced crater rims
		crater = mareSuppress * CraterNoise(point, craterMagn, craterFreq, craterSqrtDensity, craterOctaves);
        noiseOctaves    = 12.0; // Increase the number of octaves for more detailed noise
        noiseLacunarity = 2.3;
        crater = 0.25 * crater + 0.05 * crater * iqTurbulence(point * montesFreq + Randomize, 0.55);
        
		// Young terrain - suppress craters
        noiseOctaves = 4.0;
        vec3 youngDistort = Fbm3D((point - Randomize) * 0.07) * 1.1;
        noiseOctaves = 8.0;
        float young = 1.0 - Fbm(point + youngDistort);
        young = smoothstep(0.0, 1.0, young * young * young);
        crater *= young;
    }
	
	// float height = mare + crater;
	// height = saturate(mare + crater);
	
    // Ice cracks
    if (cracksOctaves > 0.0)
        height += CrackNoise(point, mask);

    if (biome > hillsFraction)
    {
        if (biome < hills2Fraction)
        {
            // "Freckles" (structures like on Europa)
            noiseOctaves    = 10.0;
            noiseLacunarity = 2.0;
            height += 0.2 * hillsMagn * mask * biomeScale * JordanTurbulence(point * hillsFreq + Randomize, 0.8, 0.5, 0.6, 0.35, 1.0, 0.8, 1.0);
        }
        else if (biome < canyonsFraction)
        {
            // Rimae
            noiseOctaves     = 4.0; // Increase the number of octaves for more detailed noise
            noiseLacunarity  = 2.5; // Increase the lacunarity for more complex noise
            noiseH           = 1.0; // Increase the noiseH for more variation in the noise
            noiseOffset      = 0.6; // Increase the noiseOffset for more variation in the noise
            p = point * 0.6 * mainFreq + Randomize; // Increase the frequency for more detailed terrain
            distort = 0.450 * Fbm3D(p * riversSin) +
                      0.045 * Fbm3D(p * riversSin * 6.0) +
                      0.015 * Fbm3D(p * riversSin * 30.0); // Increase the distortion for more rugged terrain
            cell = Cell3Noise2(canyonsFreq * 0.06 * p + distort); // Increase the frequency for more detailed canyons
            float rima = 1.0 - saturate(abs(cell.y - cell.x) * 300.0 * canyonsMagn); // Increase the multiplier for more pronounced rimae
            rima = biomeScale * smoothstep(0.0, 1.0, rima);
            height = mix(height, height-0.03, rima); // Increase the depth of the rimae
        }
        else
        {
            // Mountains
            noiseOctaves    = 12.0; // Increase the number of octaves for more detailed noise
			noiseLacunarity = 2.1; // Increase the lacunarity for more complex noise
			height += montesMagn * montBiomeScale * iqTurbulence(point * 0.6 * montesFreq + Randomize, 0.55); // Increase the frequency and turbulence for more rugged mountains
        }
    }

// Rifts
    if (riftsSin > 7.0)
	{
		float damping;
		damping = (smoothstep(1.0, 0.1, height - seaLevel)) * (smoothstep(-0.1, -0.2, seaLevel - height));
        RmRifts(point, damping, height);
	}
	
	if ((riversSin > 6.5) && (canyonsMagn < 0.52))
	{
        noiseOctaves = 5.0;
        noiseH       = 1.0;
        noiseLacunarity = 4.0;
        noiseOffset  = montesSpiky;
       
        noiseOffset  = 1.0 / (montesSpiky);
        p = point * 0.2 * mainFreq + Randomize;
        distort = 3.650 * Fbm3D(p * riversSin/5) +
                  0.650 * Fbm3D(p * riversSin) +
                  0.035 * Fbm3D(p * riversSin * 5.0);
        cell = Cell3Noise2(riversFreq * p + 0.3*distort);
        float valleys = 1.0 - (saturate(0.4 * abs(cell.y - cell.x) * riversMagn));
        valleys = smoothstep(0.0, 0.45, valleys );
        valleys *= 1.0 - smoothstep(0.13, 0.15, global - seaLevel); // disable rivers inside continents
        valleys *= 1.0 - smoothstep(-0.07, -0.05, seaLevel - global); // disable rivers inside oceans
		height = mix(height, height - 0.15, valleys);
	}
	
//PLUTO-LIKE  TERRAIN
    if ((cracksOctaves > 0.0) && (mareFreq > 1.7))
	{
		// vec3  pp = (point + Randomize) * (0.005 * hillsFreq / (hillsMagn * hillsMagn));
		vec3  pp = (point + Randomize) * 220.25;
		float fr = 0.20 * (1.5 - RidgedMultifractal(0.3*pp, 2.0));
		global += (0.00002 * (hillsFreq + 1500) / hillsMagn)*fr; 
		crater *= 1.0 - smoothstep(0.1, 0.05, global- seaLevel);
		height *= saturate(mare + crater);
		p = point *20 + Randomize;
        // distort = Fbm3D(p *0.01);
		distort = Fbm3D(point * 0.1) * 3.5+Fbm3D(point * 0.1) * 6.5+ Fbm3D(point * 0.1) * 12.5;
        // cell = Cell3Noise2(p + distort);
		cell = Cell3Noise2(canyonsFreq * 0.05 * p + distort);
		float flows = 1.0 - saturate(abs(cell.y - cell.x) * riversMagn)+0.05* iqTurbulence(point *5000, 0.55);
		smoothstep(0.0, 1.0, flows);
		flows *= 1.0 - smoothstep(0.05, -0.05, seaLevel - height);
		height = mix(height, height-0.01, flows );
	}
 
	//ENCELADUS TYPE TERRAINS
    if ((cracksOctaves > 0.0) && (canyonsMagn > 0.52) && (mareFreq < 1.7))
	{
        noiseOctaves = 5.0;
        noiseH       = 1.0;
        noiseLacunarity = 4.0;
        noiseOffset  = montesSpiky;
       
        noiseOffset  = 1.0 / (montesSpiky);
        p = point * 0.2 * mainFreq + Randomize;
        distort = 3.650 * Fbm3D(p * riversSin/5) +
                  0.650 * Fbm3D(p * riversSin) +
                  0.035 * Fbm3D(p * riversSin * 5.0);
        cell = Cell3Noise2(riversFreq * p + 0.3*distort);
        float valleys = 1.0 - (saturate(0.4 * abs(cell.y - cell.x) * riversMagn));
        valleys = smoothstep(0.0, 0.45, valleys );
        valleys *= 1.0 - smoothstep(0.13, 0.15, global - seaLevel); // disable rivers inside continents
        valleys *= 1.0 - smoothstep(-0.07, -0.05, seaLevel - global); // disable rivers inside oceans
		height = mix(height, height - 0.1, valleys);
		if (cracksFreq <0.6)
		{
			height =  saturate (height*0.3);
			noiseOctaves     = 6.0;
            noiseLacunarity  = 2.218281828459;
            noiseH           = 0.9;
            noiseOffset      = 0.5;
            p = point * 0.5* mainFreq + Randomize;
			distort = Fbm3D(point * 0.1) * 3.5+Fbm3D(point * 0.1) * 6.5+ Fbm3D(point * 0.1) * 12.5;
            cell = Cell3Noise2(canyonsFreq * 0.05 * p + distort);
            float rima2 = 2- saturate(abs(cell.y - cell.x) * 250.0 * canyonsMagn);
            rima2 = biomeScale * smoothstep(0.0, 1.0, rima2);
			height = mix(height, height-0.08, -rima2);

			noiseOctaves = 1;
			height -= 0.5*CrackNoise(point, mask);
			distort = Fbm3D(point * 0.1) * 3.5;
			float venus2 = (Fbm(point + distort)*1.5)*0.5;
			height = mix(height, height-0.2, venus2);
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

		float x = smoothstep (0.0, 300.0, 1.0 - saturate ( 2.0 * c));
		height = mix(height, height + 0.02, x);

		float x1 = smoothstep (0.0, 0.3, 1.0 - saturate ( 6.0 * c));
		height = mix(height, height - 0.01, x1);

		p *= 1.5;
		cell =  Cell3Noise2(riversFreq * (p * p)   + 2*distort);
		c = abs(cell.y - cell.x) * riversMagn;       

		float y = smoothstep (0.0, 0.7, 1.0 - saturate ( 2.0 * c));
		height = mix(height, height + 0.0025 , y);

		float y1 = smoothstep (0.0, 0.2, 1.0 - saturate ( 6.0 * c));
		height = mix(height, height - 0.0025 , y1);

		p *= 2;
		cell =  Cell3Noise2(riversFreq * (p * p)   + 4*distort);
		c = abs(cell.y - cell.x) * riversMagn;       

		float z = smoothstep (0.0, 0.7, 1.0 - saturate ( 2.0 * c));
		height = mix(height, height + 0.001 , z);

		float z1 = smoothstep (0.0, 0.2, 1.0 - saturate ( 6.0 * c));
		height = mix(height, height - 0.001 , z1);

		p *= 0.5*p;
		cell =  Cell3Noise2(riversFreq * (p * p)   + 8*distort);
		c = abs(cell.y - cell.x) * riversMagn;      

		float k = smoothstep (0.0, 1.5, 1.0 - saturate ( 2.0 * c));
		height = mix(height, height + 0.0005 , k);

		float k1 = smoothstep (0.0, 0.3, 1.0 - saturate ( 6.0 * c));
		height = mix(height, height - 0.0005 , k1);

		height +=  saturate(global) * (0.8*crater);
	}

	else
	{
		height += saturate(mare + crater);
		
		noiseOctaves = 8.0;
		float zr = 1.0 - Fbm((point + distort) * 0.78)+0.20 * (1.5 - RidgedMultifractal(pp, 2.0)) + 0.05 * (1.5 - RidgedMultifractalEroded(pp * 10.0,  2.0, 0.5*erosion)) + 0.04 * (1.5 - RidgedMultifractal(pp * 100.0, 4.0));
		zr = smoothstep(0.0, 1.0, 0.2*zr*zr);
		zr *= 1 - smoothstep(0.0, 0.02, seaLevel-global);
		zr = 0.1*hillsFreq* smoothstep(0.0, 1.0, zr);
		global =  mix(global,global+0.0006,zr);
		
        float rr  = 0.3*((0.15 * iqTurbulence(point * 0.4 * montesFreq +Randomize, 0.45)) * (RidgedMultifractalDetail(point * point * montesFreq *0.8+ venus + Randomize, 1.0, montBiomeScale)));
		rr *= 1 - smoothstep(0.0, 0.02, seaLevel-global);
		global += rr;
		
		global = 0.9 * global + 0.06 * (fr * zr * rr);
	}
	
	/*
	if (cracksOctaves < 2.0)
	{
		float crater *=0.5;
	}
	*/
    // Equatorial ridge
    if (eqridgeMagn > 0.0)
    {
        noiseOctaves = 4.0;
        float x = point.y / eqridgeWidth;
        float ridgeHeight = exp(-0.5 * x*x);
        float ridgeModulate = saturate(1.0 - eqridgeModMagn * (Fbm(point * eqridgeModFreq - Randomize) * 0.5 + 0.5));
        height += eqridgeMagn * ridgeHeight * ridgeModulate;
    }

    // Rayed craters
    if (craterSqrtDensity * craterSqrtDensity * craterRayedFactor > 0.05 * 0.05)
    {
        heightFloor = -0.5;
        heightPeak  =  0.6;
        heightRim   =  1.0;
        float craterRayedSqrtDensity = craterSqrtDensity * sqrt(craterRayedFactor);
        float craterRayedOctaves = floor(craterOctaves * craterRayedFactor);
        float craterRayedMagn = craterMagn * pow(0.62, craterOctaves - craterRayedOctaves);
        crater = RayedCraterNoise(point, craterRayedMagn, craterFreq, craterRayedSqrtDensity, craterRayedOctaves);
        height += crater;
    }

    // Shield volcano
    if (volcanoOctaves > 0)
        height = VolcanoNoise(point, global, height);

	height = mix(height, height + 0.00001, rocks);


//RODRIGO - TERRAIN NOISE MATCH ALBEDO NOISE

	noiseOctaves    = 14.0;
	noiseLacunarity = 2.218281828459;
	distort = Fbm3D((point + Randomize) * 0.07) * 1.5;
	float vary = 1.0 - 5*(Fbm((point + distort) * (1.5 - RidgedMultifractal(pp, 8.0)+ RidgedMultifractal(pp*0.999, 8.0))));
	height += saturate(0.0001*vary );

    // smoothly limit the height
    height = softPolyMin(height, 0.99, 0.3);
    height = softPolyMax(height, 0.05, 0.1);

    return height;
}

//-----------------------------------------------------------------------------

void main()
{
    vec3  point = GetSurfacePoint();
    float height = HeightMapSelena(point);
    OutColor = vec4(height);
}

//-----------------------------------------------------------------------------

#endif
