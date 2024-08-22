#include "tg_common.glh"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------
// Non-uniform droplet erosion function
//-----------------------------------------------------------------------------

vec3 NonUniformDropletErosion(vec3 point, float erosionStrength, float time)
{
    // Parameters for droplet erosion
    float dropletRadius = 0.1;
    float dropletFalloff = 0.5;
    float erosionFactor = 0.8;

    // Calculate erosion effect based on position and time
    float distance = length(point.xy);
    float erosionEffect = exp(-distance * dropletFalloff) * erosionStrength;

    // Apply erosion effect to the point
    vec3 erodedPoint = point;
    erodedPoint.z -= erosionEffect * erosionFactor * sin(time + distance);

    return erodedPoint;
}

//-----------------------------------------------------------------------------
// Ridged multifractal with "non-uniform droplet erosion"

float RidgedMultifractalDroplet(vec3 point, float gain, float erosionStrength, float time)
{
    float frequency = 1.0;
    float amplitude = 1.0;
    float summ = 0.0;
    float signal = 1.0;
    float weight;
    vec3 dsum = vec3(0.0);
    vec4 noiseDeriv;
    for (int i = 0; i < noiseOctaves; ++i)
    {
        vec3 erodedPoint = NonUniformDropletErosion(point + dsum, erosionStrength, time);
        noiseDeriv = NoiseDeriv(erodedPoint * frequency);
        weight = saturate(signal * gain);
        signal = noiseOffset - sqrt(noiseRidgeSmooth + noiseDeriv.w * noiseDeriv.w);
        signal *= signal * weight;
        amplitude = pow(frequency, -noiseH);
        summ += signal * amplitude;
        frequency *= noiseLacunarity;
        dsum -= amplitude * noiseDeriv.xyz * noiseDeriv.w;
    }
    return summ;
}

//-----------------------------------------------------------------------------
// Ridged multifractal detail with "non-uniform droplet erosion"

float RidgedMultifractalDropletDetail(vec3 point, float gain, float erosionStrength, float time, float firstOctaveValue)
{
    float frequency = 1.0;
    float amplitude = 1.0;
    float summ = firstOctaveValue;
    float signal = firstOctaveValue;
    float weight;
    vec3 dsum = vec3(0.0);
    vec4 noiseDeriv;
    for (int i = 0; i < noiseOctaves; ++i)
    {
        vec3 erodedPoint = NonUniformDropletErosion(point + dsum, erosionStrength, time);
        noiseDeriv = NoiseDeriv(erodedPoint * frequency);
        weight = saturate(signal * gain);
        signal = noiseOffset - sqrt(noiseRidgeSmooth + noiseDeriv.w * noiseDeriv.w);
        signal *= signal * weight;
        amplitude = pow(frequency, -noiseH);
        summ += signal * amplitude;
        frequency *= noiseLacunarity;
        dsum -= amplitude * noiseDeriv.xyz * noiseDeriv.w;
    }
    return summ;
}

//-----------------------------------------------------------------------------
//	RODRIGO - SMALL CHANGES TO RIVERS AND RIFTS
// Modified Rodrigo's rivers

void    RmPseudoRivers(vec3 point, float global, float damping, inout float height)
{
    noiseOctaves = 8.0;
        noiseH       = 1.0;
        noiseLacunarity = 2.1;

       
    vec3 p = point * 2.0* mainFreq + Randomize;
    vec3 distort = 0.325 * Fbm3D(p * riversSin);
    distort = 0.65 * Fbm3D(p * riversSin) +
                  0.03 * Fbm3D(p * riversSin * 5.0) + 0.01* RidgedMultifractalErodedDetail(point * 0.3* (canyonsFreq+1000)*(0.5*(1/montesSpiky+1))  + Randomize, 8.0, erosion, 2);


    vec2 cell = 2.5* Cell3Noise2(riversFreq * p + 0.5*distort);
        
    float valleys = 1.0 - (saturate(0.36 * abs(cell.y - cell.x) * riversMagn));
    valleys = smoothstep(0.0, 1.0, valleys) * damping;
    height = mix(height, seaLevel + 0.03, valleys);


    float rivers = 1.0 - (saturate(6.5 * abs(cell.y - cell.x) * riversMagn));
    rivers = smoothstep(0.0, 1.0, rivers) * damping;
    height = mix(height, seaLevel+0.015, rivers);
}

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

float   HeightMapTerra(vec3 point, out vec4 HeightBiomeMap)
{
	// Assign a climate type
		noiseOctaves = (oceanType == 1.0) ? 5.0 : 12.0;
		noiseH          = 0.5;
		noiseLacunarity = 2.218281828459;
		noiseOffset     = 0.8;
		float climate, latitude;
		if (tidalLock <= 0.0)
		{
			latitude = abs(point.y);
			latitude += 0.15 * (Fbm(point * 0.7 + Randomize) - 1.0);
			latitude = saturate(latitude);
			if (latitude < latTropic - tropicWidth)
				climate = mix(climateTropic, climateEquator, saturate((latTropic - tropicWidth - latitude) / latTropic));
			else if (latitude > latTropic + tropicWidth)
				climate = mix(climateTropic, climatePole, saturate((latitude - latTropic - tropicWidth) / (1.0 - latTropic)));
			else
				climate = climateTropic;
		}
		else
		{
			latitude = 1.0 - point.x;
			latitude += 0.15 * (Fbm(point * 0.7 + Randomize) - 1.0);
			climate = mix(climateTropic, climatePole, saturate(latitude));
		}

	// Litosphere cells
		// float lithoCells = LithoCellsNoise(point, climate, 1.5);

	// Global landscape
		vec3 p = point * mainFreq + Randomize;
		noiseOctaves = 6; // Increase the number of octaves for more detail
		vec3 distort = 0.35 * Fbm3D(p * 0.73);
		noiseOctaves = 5; // Increase the number of octaves for more detail
		distort += 0.01 * (1.0 - abs(Fbm3D(p * 132.3))); // Increase the distortion for more varied landscapes
		float global = 1.0 - Cell3Noise(p + distort);

    // Make sea bottom more flat; shallow seas resembles those on Titan;
    // but this shrinks out continents, so value larger than 1.5 is unwanted
    global = softPolyMax(global, 0.0, 0.1);
    global = pow(global, 1.5);

	// Venus-like structure
		float venus = 0.0;
		// if (venusMagn > 0.05)
		// {
			noiseOctaves = 4;
			distort = Fbm3D(point * 0.3) * 1.5;
			noiseOctaves = 6;
			// venus = Fbm((point + distort) * venusFreq) * (venusMagn+0.3);
			venus = Fbm((point + distort) * venusFreq) * (venusMagn + 0.3 * float(venusMagn > 0.05));
		// }
		global = (global + venus - seaLevel) * 0.5 + seaLevel;
		float shore = saturate(70.0 * (global - seaLevel));
			// noiseOctaves = 8;
			// vec3  pp = (point + Randomize) * 22.25;

	// Biome domains
		noiseOctaves = 6;
		p = p * 2.3 + 13.5 * Fbm3D(p * 0.06);
		vec4  col;
		vec2  cell = Cell3Noise2Color(p, col);
		float biome = col.r;
		float biomeScale = saturate(2.0 * (pow(abs(cell.y - cell.x), 0.7) - 0.05));
		float terrace = col.g;
		float terraceLayers = max(col.b * 10.0 + 3.0, 3.0);
			terraceLayers += Fbm(p * 5.41);
		float montRange = saturate(DistNoise(point * 22.6 + Randomize, 2.5) + 0.5);
			montRange *= montRange;
		float montBiomeScale = min(pow(2.2 * biomeScale, 3.0), 1.0) * montRange;
		float inv2montesSpiky = 1.0 /(montesSpiky*montesSpiky);
		float heightD = 0.0;
		float height = 0.0;
		float landform = 0.0;
		float dist;
		
		noiseOctaves = 8;
		vec3  pp = (point + Randomize) * (0.0005 * hillsFreq / (hillsMagn * hillsMagn));
		
		noiseOctaves = 12.0;
		distort = Fbm3D((point + Randomize) * 0.07) * 1.5;
		
		noiseOctaves = 10.0;
		noiseH       = 1.0;
		noiseLacunarity = 2.3;
		noiseOffset  = montesSpiky;
		float rocks = -0.005 * iqTurbulence(point * 200.0, 1.0);
		
		//small terrain elevations   
		noiseOctaves = 12.0;
		distort = Fbm3D((point + Randomize) * 0.07) * 1.5;
		
		noiseOctaves = 8.0;
		float fr = 0.20 * (1.5 - RidgedMultifractal(pp, 2.0)) + 0.05 * (1.5 - RidgedMultifractal(pp * 10.0,  2.0));
			fr *= 1 - smoothstep(-0.01, 0.02, seaLevel-global);
		
		noiseOctaves = 8.0;
		float zr = 1.0 - Fbm((point + distort) * 0.78)+0.20 * (1.5 - RidgedMultifractal(pp, 2.0)) + 0.05 * (1.5 - RidgedMultifractalEroded(pp * 10.0,  2.0, 0.5*erosion)) + 0.04 * (1.5 - RidgedMultifractal(pp * 100.0, 4.0));
		zr = smoothstep(0.0, 1.0, 0.2*zr*zr);
		zr *= 1 - smoothstep(0.0, 0.02, seaLevel-global);
		zr = 0.1*hillsFreq* smoothstep(0.0, 1.0, zr);
		global =  mix(global,global+0.0006,zr);
		
        float rr  = 0.3*((0.15 * iqTurbulence(point * 0.4 * montesFreq +Randomize, 0.45)) * (RidgedMultifractalDetail(point * point * montesFreq *0.8+ venus + Randomize, 1.0, montBiomeScale)));
		rr *= 1 - smoothstep(0.0, 0.02, seaLevel-global);
		global += rr;

	if (oceanType > 0.0)
	{
		fr *= 3;
	}
	global = 0.9 * global + 0.06 * (fr * zr * rr);
	// global = 0.9 * global + 0.06 * fr;

	//Eroded terrain & Mesas
		float t1 = 1.0; 
			t1 *= 1.0 - smoothstep(0.05, 0.105, global-seaLevel); 
		t1 *= 1.0 - smoothstep(-0.05, -0.025, seaLevel - global); 
			height = mix(height, height + 0.008, t1);
		float t2 = 1.0; 
			t2 *= 1.0 - smoothstep(0.13, 0.185, global-seaLevel); 
		t2 *= 1.0 - smoothstep(-0.13, -0.105, seaLevel - global); 
			height = mix(height, height + 0.010, t2);
		float t4 = 1.0; 
			t4 *= 1.0 - smoothstep(0.21, 0.265, global-seaLevel); 
		t4*= 1.0 - smoothstep(-0.21, -0.185, seaLevel - global); 
			height = mix(height, height + 0.010, t4);
		float t6 = 1.0; 
			t6*= 1.0 - smoothstep(-0.29, -0.265, global-seaLevel); 
		height = mix(height, height + 0.010, t6);

	if (biome < dunesFraction)
	{
		if (dunesFraction > 0.105)
		{
			// Dunes
			noiseOctaves = 2.0;
			dist = dunesFreq + Fbm(p * 1.21);
			float desert = max(Fbm(p * dist), 0.0);
			float dunes  = DunesNoise(point, 3);
			landform = (0.0002 * desert + dunes) * pow(biomeScale, 3);
			// heightD = 0.2 * max(Fbm(p * dist * 0.3) + 0.7, 0.0);
			// heightD = biomeScale * dunesMagn * (heightD + DunesNoise(point, 3));
			heightD += dunesMagn * landform;
		}
		else
		{
			// Star Dunes
			// vec3 twistedPoint = point;
			noiseOctaves = 10.0;
			noiseH       = 100;
			noiseLacunarity = 2.1;
			dist = dunesFreq + Fbm(p * 1.21);
			heightD = max(Fbm(p * dist * 0.3) + 0.7, 0.0);
			heightD = 0.2 * max(Fbm(p * dist * 0.3) + 0.7, 0.0);
			heightD = biomeScale * dunesMagn * (JordanTurbulence(point * (dunesFreq / 3) + Randomize, 0.8, 0.5, 0.6, 0.35, 1.0, 0.8, 1.0) * (dunesMagn * 100)) * (RidgedMultifractalErodedDetail(point * (dunesFreq * 1.75) + Randomize, 2.0, (erosion * 1.5), biomeScale) * dunesMagn);
		}
	}
	else if (biome < hillsFraction)
	{
		// Mountains
		if (oceanType > 0.0)
		{
			noiseOctaves = 10.0;
			noiseH       = 1.0;
			noiseLacunarity = 2.0;
			noiseOffset  = montesSpiky * 1.2;
			height = hillsMagn * 2.4 * ((1.25 + iqTurbulence(point * 0.5 * hillsFreq * inv2montesSpiky * 1.25 + Randomize, 0.55)) * (0.05 * RidgedMultifractalErodedDetail(point * 1.0 * hillsFreq * inv2montesSpiky * 1.5 + Randomize, 1.0, erosion, montBiomeScale)));
		}
		else
		{
			noiseOctaves = 10.0;
			noiseH       = 1.0;
			noiseLacunarity = 2.0;
			noiseOffset  = montesSpiky * 1.2;
			height = hillsMagn * 7.5 * ((1.25 + iqTurbulence(point * 0.5 * (hillsFreq / 2) * inv2montesSpiky * 1.25 + Randomize, 0.55)) * (0.05 * RidgedMultifractalErodedDetail(point * 1.0 * (hillsFreq / 2) * inv2montesSpiky * 1.5 + Randomize, 1.0, erosion, montBiomeScale)));
		}
	}
	else if (biome < hills2Fraction)
	{
		// "Eroded" hills
		if (oceanType > 0.0)
		{
			noiseOctaves = 10.0;
			noiseH       = 1.0;
			noiseOffset  = venusFreq;
			noiseLacunarity = 2.1;
			height = (0.5 + 0.4 * iqTurbulence(point * 0.5 * hillsFreq *  + Randomize, 0.55)) * (biomeScale * hillsMagn * (0.05 - (0.4 * RidgedMultifractalDetail(point * hillsFreq + Randomize, 2.0, venus)) + 0.3 * RidgedMultifractalErodedDetail(point * hillsFreq + Randomize, 2.0, 1.1 * erosion, montBiomeScale)));
		}
		else
		{
			noiseOctaves = 8.0; // Decrease the number of octaves for smoother terrain
			noiseLacunarity = 2.0; // Slightly increase lacunarity for more variation in frequency
			height = biomeScale * hillsMagn * JordanTurbulence(point * hillsFreq + Randomize, 0.7, 0.5, 0.6, 0.35, 1.0, 0.8, 1.0);
		}
	}
	else if (biome < canyonsFraction)
	{
		if (oceanType > 0.0)
		{
			// TPE Canyons
			noiseOctaves = 10.0;
			noiseH       = 0.1;
			noiseLacunarity = 2.1;
			noiseOffset  = montesSpiky;
			height = -canyonsMagn * 4 * ((0.5 + 0.8 * iqTurbulence(point * 0.5 * (canyonsFreq * 2) + Randomize, 0.55)) * (0.1 * RidgedMultifractalDetail(point * 0.7 * (canyonsFreq * 2) + Randomize, 1.0, montBiomeScale)));
			// if (terrace < terraceProb)
			{
				terraceLayers *= 5.0;
				float h = height * terraceLayers;
				height = (floor(h) + smoothstep(0.1, 0.9, fract(h))) / terraceLayers;
			}
		}
		else
		{
			// TPE Canyons
			noiseOctaves = 8.0; // Reduced for smoother transitions
			noiseH       = 0.2; // Increased for more variation
			noiseLacunarity = 2.0; // Adjusted for smoother noise
			noiseOffset  = montesSpiky;
			height = -canyonsMagn * ((0.4 + 0.7 * iqTurbulence(point * 0.4 * (canyonsFreq * 2) + Randomize, 0.5)) * (0.08 * RidgedMultifractalDetail(point * 0.6 * (canyonsFreq * 2) + Randomize, 0.9, montBiomeScale)));
			//if (terrace < terraceProb)
			{
 			   terraceLayers *= 4.0; // Adjusted for less abrupt terracing
 			   float h = height * terraceLayers;
 			   height = (floor(h) + smoothstep(0.05, 0.85, fract(h))) / terraceLayers; // Adjusted for smoother terracing
			}
		}
	}
	else
	{
		// Mountains
		if (oceanType > 0.0)
		{
			noiseOctaves = 10.0;
			noiseH       = 1.0;
			noiseLacunarity = 2.1;
			noiseOffset  = montesSpiky;
			// height = montesMagn * 5.0 * (0.5 + 0.4 * iqTurbulence(point * 0.5 * montesFreq + Randomize, 0.55))* 0.7* montesMagn * montRange * RidgedMultifractalErodedDetail(point * montesFreq * inv2montesSpiky + Randomize, 2.0, erosion, montBiomeScale)+ 0.6 * biomeScale * hillsMagn * JordanTurbulence(point/4 * hillsFreq/4 + Randomize, 0.8, 0.5, 0.6, 0.35, 1.0, 0.8, 1.0);
			height = (0.5 + 0.4 * iqTurbulence(point * 0.5 * (montesFreq * 3) + Randomize, 0.55)) * 0.4 * montesMagn * montRange * RidgedMultifractalErodedDetail(point * (montesFreq * 3) * inv2montesSpiky + Randomize, 2.0, erosion, montBiomeScale);
		}
		else
		{
			noiseOctaves = 10.0;
			noiseH       = 1.0;
			noiseLacunarity = 2.3;
			noiseOffset  = montesSpiky;
			height = montesMagn * 5.0 * ((0.5 + 0.8 * iqTurbulence(point * 0.5 * montesFreq + Randomize, 0.55)) * (0.1 * RidgedMultifractalDetail(point *  montesFreq + venus + Randomize, 1.0, montBiomeScale)));
		}
    }

	// Mare
		float mare = global;
		float mareFloor = global;
		float mareSuppress = 1.0;
	if (oceanType > 0.0)
	{
		// mare = saturate(global);
		mare = smoothstep(-0.25, 1.26, shore * mare);
		mareFloor = 0.6 * (1.0 - Cell3Noise(0.3*p));
		// mare = softPolyMin(mare, 0.99, 0.3);
		// mare = softPolyMax(mare, 0.05, 0.1);
	}
	else
	{
		if (mareSqrtDensity > 0.05) 
		{
			// noiseOctaves = 2;
			mareFloor = 0.6 * (1.0 - Cell3Noise(0.3*p));
			noiseH           = 0.5;
			noiseLacunarity  = 2.218281828459;
			noiseOffset      = 0.8;
			craterDistortion = 1.0;
			noiseOctaves     = 6.0;  // Mare roundness distortion
			mare = MareNoise(point, global, 0.0, mareSuppress);
		}
	}

	height = (height + heightD) * shore;    // suppress all landforms inside seas
	height *= saturate(20.0 * mare);        // suppress mountains, canyons and hill (but not dunes) inside mare
	// height *= lithoCells;                   // suppress all landforms inside lava seas

	// Ice caps
		float oceaniaFade = (oceanType == 1.0) ? 0.1 : 1.0;
		float iceCap = saturate((latitude / latIceCaps - 1.0) * 5.0 * oceaniaFade);

	// Ice cracks
		float mask = 1.0;
	if (cracksOctaves > 0.0)
		height += CrackNoise(point, mask) * iceCap;

	// Craters
		float crater = 0.0;
	if (craterSqrtDensity > 0.05)
	{
		heightFloor = -0.1;
		heightPeak  =  0.6;
		heightRim   =  1.0;
		crater = CraterNoise(point, 0.5 * craterMagn, craterFreq, craterSqrtDensity, craterOctaves);
		noiseOctaves    = 10.0;
		noiseH       = 1.0;
		noiseOffset  = 1.0;
		noiseLacunarity = 2.0;
		crater = 0.25 * crater + 0.04 * craterMagn;
		if (erosion > 0)
		{
			crater = (crater * 0.25) - seaLevel * (craterSqrtDensity * seaLevel * 0.025);
			height = height + (seaLevel * -0.5);
			heightPeak = 0.6 * RidgedMultifractalErodedDetail(point * 0.3 * craterFreq + Randomize, 2.0, erosion, 0.25 * crater);
			if (craterOctaves == 0)
			{
				height = height + (seaLevel * 0.5);
			}
		}
		else if (erosion == 0)
		{
			height = height - crater * craterMagn * iqTurbulence(point * craterFreq + Randomize, 0.55) + (seaLevel * -0.5);
		}
		
        // Young terrain - suppress craters
        noiseOctaves = 4.0;
        vec3 youngDistort = Fbm3D((point - Randomize) * 0.07) * 1.1;
        noiseOctaves = 4.0;
        float young = 1.0 - Fbm(point + youngDistort);
        young = smoothstep(0.0, 1.0, young * young * young);
        crater *= young;
	}
	height += mare + crater;
	
	// Pseudo rivers -- Adjusted using some of Rodrigo's code
	float rodrigoDamping;
	rodrigoDamping = global - seaLevel - rodrigoDamping;
	float damping;
	if (oceanType > 0.0)
	{
		if (erosion >= 0.101)
		{
			noiseOctaves = 12.0;
			noiseH       = 0.8;
			noiseLacunarity = 2.3;
			p = point * 2.0* mainFreq + Randomize;
			distort = 0.65 * Fbm3D(p * riversSin) + 0.03 * Fbm3D(p * riversSin * 5.0) + 0.01* RidgedMultifractalErodedDetail(point * 0.3* (canyonsFreq+1000)*(0.5*(inv2montesSpiky+1))  + Randomize, 8.0, erosion, montBiomeScale*2);
			cell = 2.5* Cell3Noise2(riversFreq * p + 0.5*distort);
			float pseudoRivers2 = 1.0 - (saturate(0.36 * abs(cell.y - cell.x) * riversMagn));
				pseudoRivers2 = smoothstep(0.25, 0.99, pseudoRivers2); 
				pseudoRivers2 *= 1.0 - smoothstep(0.055, 0.065, rodrigoDamping); // disable rivers inside continents
				pseudoRivers2 *= 1.0 - smoothstep(0.000, 0.0001, seaLevel - height); // disable rivers inside oceans
				height = mix(height, seaLevel+0.003, pseudoRivers2);
				cell = 2.5* Cell3Noise2(riversFreq * p + 0.5*distort);
			float RmPseudoRivers = 1.0 - (saturate(2.8 * abs(cell.y - cell.x) * riversMagn));
				RmPseudoRivers = smoothstep(0.0, 1.0, RmPseudoRivers); 
				RmPseudoRivers *= 1.0 - smoothstep(0.055, 0.057, global-seaLevel); 
				RmPseudoRivers *= 1.0 - smoothstep(0.00, 0.005, seaLevel - height); // disable rivers inside oceans
				height = mix(height, seaLevel-0.0035, RmPseudoRivers);
				damping = (smoothstep(0.045, 0.035, rodrigoDamping)) *    // disable rivers inside continents
                        (smoothstep(-0.0016, -0.018, seaLevel - height));  // disable rivers inside oceans
				PseudoRivers(point, global, damping, height);
		}
		else
		{
			noiseOctaves    = riversSin;
			noiseLacunarity = 2.218281828459;
			noiseH          = 0.5;
			noiseOffset     = 0.8;
			p = point * mainFreq + Randomize;
			distort = 0.350 * Fbm3D(p * riversSin) + 0.035 * Fbm3D(p * riversSin * 5.0) + 0.010 * Fbm3D(p * riversSin * 25.0);
			cell = Cell3Noise2(riversFreq * p + distort);
			float RmPseudoRivers = 1.0 - saturate(abs(cell.y - cell.x) * riversMagn);
			RmPseudoRivers = smoothstep(0.0, 1.0, RmPseudoRivers);
			RmPseudoRivers *= 1.0 - smoothstep(0.06, 0.10, rodrigoDamping); // disable rivers inside continents
			RmPseudoRivers *= 1.0 - smoothstep(0.00, 0.01, seaLevel - height); // disable rivers inside oceans
			height = mix(height, seaLevel-0.02, RmPseudoRivers);
				damping = (smoothstep(0.045, 0.035, rodrigoDamping)) *    // disable rivers inside continents
                        (smoothstep(-0.0016, -0.018, seaLevel - height));  // disable rivers inside oceans
				PseudoRivers(point, global, damping, height);
		}
	}
	else
	{
		noiseOctaves = 14.0;
		noiseH       = 1;
		noiseLacunarity = 2.1;
		noiseOffset  = 1.0 / (montesSpiky);
		p = point * 0.2 * mainFreq + Randomize;
		distort = 0.25 * Fbm3D(p * riversSin) + 0.015 * Fbm3D(p * riversSin * 5.0) + (0.001*RidgedMultifractalEroded(point *  canyonsFreq + Randomize,8.0, erosion));
		cell = 1.5*Cell3Noise2(riversFreq * p + 1.5*distort);
		float valleys = 1.0 - (saturate(2.385 * abs(cell.y - cell.x) * riversMagn));
			valleys = smoothstep(0.0, 0.45, valleys );
			valleys *= 1.0 - smoothstep(0.09, 0.14, rodrigoDamping); // disable rivers inside continents
			valleys *= 1.0 - smoothstep(-0.05, 0.005, seaLevel - height); // disable rivers inside oceans
			height = mix(height, seaLevel - 0.005, valleys);
			p = point * 0.8* mainFreq + Randomize;
			distort = 0.15 * Fbm3D(p * riversSin) + 0.03 * Fbm3D(p * riversSin * 5.0) + 0.01* RidgedMultifractalErodedDetail(point * 0.3* (canyonsFreq+1000)*(0.5*(inv2montesSpiky+1))  + Randomize, 8.0, erosion, montBiomeScale*20);
			cell = Cell3Noise2(riversFreq * p + 0.5*distort);
		float valleys2 = 1.0 - (saturate(1.35 * abs(cell.y - cell.x) * riversMagn));
			valleys2 = smoothstep(0.0, 0.8, valleys2 );
			valleys2 *= 1.0 - smoothstep(0.26, 0.27, rodrigoDamping); // disable rivers inside continents
			valleys2 *= 1.0 - smoothstep(-0.26, -0.25, seaLevel - height); // disable rivers inside oceans
			height = mix(height, height - 0.02, valleys2);
				damping = (smoothstep(0.045, 0.035, rodrigoDamping)) *    // disable rivers inside continents
                        (smoothstep(-0.0016, -0.018, seaLevel - height));  // disable rivers inside oceans
				RmPseudoRivers(point, global, damping, height);
	}

    // Rifts
    if (riftsMagn > 0.0)
	{
		damping = (smoothstep(1.0, 0.1, height - seaLevel)) * (smoothstep(-0.1, -0.2, seaLevel - height));
        RmRifts(point, damping, height);
	}
	
	// Shield volcano
		if (volcanoOctaves > 0)
		height = VolcanoNoise(point, global, height);

	// Mountain glaciers
    if (climate > 0.9)
    {
		noiseOctaves = 4.0; // Reduced for more natural variation
		noiseLacunarity = 2.5; // Adjusted for smoother transitions
		float glacierVary = Fbm(point * 1500.0 + Randomize); // Adjusted scale for more realistic glacier patterns
		float snowLine = (height + 0.2 * glacierVary - snowLevel) / (1.0 - snowLevel); // Subtle variation along the snowline
		height += 0.0003 * smoothstep(0.0, 0.25, snowLine); // Adjusted for gradual buildup of glaciers
	}

	// Apply ice caps
		height = height * oceaniaFade + icecapHeight * 10.0 * smoothstep(0.0, snowLevel, iceCap) * ((RidgedMultifractalErodedDetail(point * (venusFreq + dunesFreq) + Randomize, 2.0, (erosion * 1.5), iceCap) * icecapHeight + 9.2) * 0.1);
		// height = height * oceaniaFade + icecapHeight * smoothstep(0.0, 1.0, iceCap);
		
		noiseLacunarity = 2.218281828459;
		noiseOctaves = 12.0;
		p = point * 0.5*mainFreq + Randomize;
		distort = 0.05 * Fbm3D(p * riversSin) + 0.035 * Fbm3D(p * riversSin * 5.0) + (0.001*RidgedMultifractalEroded(point *  canyonsFreq + Randomize,8.0, erosion));
		cell = Cell3Noise2(riversFreq * p + 1.5*distort);
		distort = Fbm3D((point + Randomize) * 0.07) * 1.5;
		
		p = point * (colorDistFreq * 0.005) + vec3(zr);
		p += Fbm3D(p * 0.38) * 1.2;
		float vary = 1.0 - 5*(Fbm((point + distort) * (1.5 - RidgedMultifractal(pp,         8.0)+ RidgedMultifractal(pp*0.999, 8.0))));
		vary = Fbm(p) * 0.35 + 0.245;
		height = mix(height, height + 0.00015, vary);
		
    // smoothly limit the height
    height = softPolyMin(height, 0.99, 0.3);
    height = softPolyMax(height, 0.05, 0.1);
    
	if (riversMagn > 0.0)
	{
		HeightBiomeMap = vec4(height-0.06);
	}
	else
	{
		HeightBiomeMap = vec4(height);
	}
	
	return height;
}

//-----------------------------------------------------------------------------

void main()
{
	vec3  point = GetSurfacePoint();
	float height = HeightMapTerra(point, OutColor);
	OutColor = vec4(height);
}

//-----------------------------------------------------------------------------

#endif

