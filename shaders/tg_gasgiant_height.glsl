#include "tg_common.glh"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

vec3    TurbulenceGasGiantTPE(vec3 point)
{
    const float scale = 0.7;

    vec3  twistedPoint = point;
    vec3  cellCenter;
    vec2  cell;
    float r, fi, rnd, dist, dist2, dir;
    float strength = 5.5;
    float freq = 800 * scale;
    float size = 15.0 * scale;
    float dens = 0.8;

    for (int i = 0; i<5; i++)
    {
        vec2  cell = inverseSF(point, freq, cellCenter);
        rnd = hash1(cell.x);
        r = size * cell.y;

        if ((rnd < dens) && (r < 1.0))
        {
            dir = sign(0.5 * dens - rnd);
            dist = saturate(1.0 - r);
            dist2 = saturate(0.5 - r);
            fi = pow(dist, strength) * (exp(-6.0 * dist2) + 0.25);
            twistedPoint = Rotate(dir * stripeTwist * sign(cellCenter.y) * fi, cellCenter.xyz, point);
        }

        freq = min(freq * 2.0, 1600.0);
        size = min(size * 1.2, 30.0);
        strength = strength * 1.5;
        point = twistedPoint;
    }

    return twistedPoint;
}

//-----------------------------------------------------------------------------

vec3    CycloneNoiseGasGiantTPE(vec3 point, inout float offset)
{
    vec3  rotVec = normalize(Randomize);
    vec3  twistedPoint = point;
    vec3  cellCenter;
    vec2  cell;
    float r, fi, rnd, dist, dist2, dir;
    float offs = 0.6;
    float squeeze = 1.7;
    float strength = 2.5;
    float freq = cycloneFreq * 50.0;
    float dens = cycloneDensity * 0.02;
    float size = 6.0;

    for (int i = 0; i<cycloneOctaves; i++)
    {
        cell = inverseSF(vec3(point.x, point.y * squeeze, point.z), freq, cellCenter);
        rnd = hash1(cell.x);
        r = size * cell.y;

        if ((rnd < dens) && (r < 1.0))
        {
            dir = sign(0.7 * dens - rnd);
            dist = saturate(1.0 - r);
            dist2 = saturate(0.5 - r);
            fi = pow(dist, strength) * (exp(-6.0 * dist2) + 0.5);
            twistedPoint = Rotate(cycloneMagn * dir * sign(cellCenter.y + 0.001) * fi, cellCenter.xyz, point);
            offset += offs * fi * dir;
        }

        freq = min(freq * 2.0, 6400.0);
        dens = min(dens * 3.5, 0.3);
        size = min(size * 1.5, 15.0);
        offs = offs * 0.85;
        squeeze = max(squeeze - 0.3, 1.0);
        strength = max(strength * 1.3, 0.5);
        point = twistedPoint;
    }

    return twistedPoint;
}

//-----------------------------------------------------------------------------

float   HeightMapCloudsGasGiantTPE(vec3 point)
{
    vec3  twistedPoint = point;

float coverage = cloudsCoverage;

    // Compute zones
    float zones = Noise(vec3(0.0, twistedPoint.y * stripeZones * 0.5, 0.0)) * 0.6 + 0.25;
    float offset = 0.0;

    // Compute cyclons
    if (cycloneOctaves > 0.0)
        twistedPoint = CycloneNoiseGasGiantTPE(twistedPoint, offset);

    // Compute turbulence
    twistedPoint = TurbulenceGasGiantTPE(twistedPoint);

    // Compute stripes
    noiseOctaves = cloudsOctaves;
    float turbulence = Fbm(twistedPoint * 2.2);
    twistedPoint = twistedPoint * (0.05 * cloudsFreq) + Randomize;
    twistedPoint.y *= 100.0 + turbulence;
    float height = stripeFluct * (Fbm(twistedPoint) * 0.7 + 0.5);

    return zones+ height + offset;
}

//-----------------------------------------------------------------------------

void main()
{
    if (cloudsLayer == 0.0)
    {
        vec3  point = GetSurfacePoint();
        // float height = HeightMapCloudsGasGiant(point);
        float height = HeightMapCloudsGasGiantTPE(point);
        OutColor = vec4(height);
    }
    else
        OutColor = vec4(0.0);
}

//-----------------------------------------------------------------------------

#endif
