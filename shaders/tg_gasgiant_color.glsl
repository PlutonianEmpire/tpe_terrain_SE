#include "tg_common.glh"

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

float   HeightMapFogGasGiant(vec3 point)
{
    return 0.85 + 0.35 * Noise(point * vec3(0.25, 7.0, 0.25));
}

//-----------------------------------------------------------------------------

void main()
{
    if (cloudsLayer == 0.0)
    {
		float height = GetSurfaceHeight();
		vec3 color = height * GetGasGiantCloudsColor(height).rgb;
		float minColor = min(min(color.r, color.g), color.b);
		float maxColor = max(max(color.r, color.g), color.b);
		float averageMinMax = (minColor + maxColor) / 2.0; // Calculate average of min and max color
		OutColor.rgb = mix(vec3(averageMinMax), color, 2.5);
		OutColor.a = 1.0 * dot(OutColor.rgb, vec3(1.0, 1.0, 1.0));
	}
	else
	{
		float height = HeightMapFogGasGiant(GetSurfacePoint());
		vec3 color = height * GetGasGiantCloudsColor(1.0).rgb;
		float minColor = min(min(color.r, color.g), color.b);
		float maxColor = max(max(color.r, color.g), color.b);
		float averageMinMax = (minColor + maxColor) / 2.0; // Calculate average of min and max color
		OutColor.rgb = mix(vec3(averageMinMax), color, 1);
		OutColor.a *= 0.5 * dot(OutColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    }
    OutColor.rgb = pow(OutColor.rgb, (colorGamma / 1.75));
}

//-----------------------------------------------------------------------------

#endif
