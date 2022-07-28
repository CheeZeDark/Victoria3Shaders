Includes = {
	"cw/utility.fxh"
	"cw/camera.fxh"
}

ConstantBuffer( GameSharedConstants )
{
	float2 MapSize;
	float2 ProvinceMapSize;

	float4 SSAOColorMesh;
	float4 MeshTintColor;
	float4 DecentralizedCountryColor;
	float4 ImpassableTerrainColor;

	float GlobalTime;
	float FlatMapHeight;
	float FlatMapLerp;

	float ShorelineMaskBlur;
	float ShorelineExtentStr;
	float ShorelineAlpha;
	int	  ShoreLinesUVScale;

	int ImpassableTerrainTiling
	float ImpassableTerrainHeight
	float ImpassableTerrainFadeStart
	float ImpassableTerrainFadeEnd

	float WaterShadowMultiplier;

	float MeshTintHeightMin;
	float MeshTintHeightMax;
	float SSAOAlphaTrees;
	float SSAOAlphaTerrain;

	float FogCloseOffset;
	float FogFarOffset;
	float FogWidthScale;

	int _MapPaintingTextureTiling;

	bool _UseMapmodeTextures;
};

Code
[[
	float4 AlphaBlend_AOverB( float4 A, float4 B )
	{
		float Alpha = A.a + B.a * ( 1.0f - A.a );
		float3 Color = A.rgb * A.a + B.rgb * B.a * ( 1.0f - A.a );
		Color /= clamp( Alpha, 0.01f, 1.0f );
		return float4( Color, Alpha );
	}

	// Vertical Rays
	float RayValue( in float2 coord, in float frequency, in float travelRate, in float maxStrength )
	{
		float ny = 2.0f * ( coord.y - 0.5f );
		float ny2 = min( 1.0f, 2.5f - 2.5f * ny * ny );

		float xModifier = 1.0f * ( cos( GlobalTime * travelRate + coord.x * frequency ) - 0.5f );
		float yModifier = sin( coord.y );
		return maxStrength * xModifier * yModifier * ny2;
	}

	float Hash1_2( in float2 x )
	{
		return frac( sin( dot( x, float2( 52.127f, 61.2871f) ) ) * 521.582f );
	}

	float2 Hash2_2( in float2 x )
	{
		return frac( sin( mul( Create2x2( 20.52f, 24.1994f, 70.291f, 80.171f ),  x ) * 492.194 ) );
	}

	float2 Noise2_2( float2 uv )
	{
		float2 f = smoothstep( 0.0f, 1.0f, frac( uv ) );

		float2 uv00 = floor( uv );
		float2 uv01 = uv00 + float2( 0, 1 );
		float2 uv10 = uv00 + float2( 1, 0 );
		float2 uv11 = uv00 + 1.0f;
		float2 v00 = Hash2_2( uv00 );
		float2 v01 = Hash2_2( uv01 );
		float2 v10 = Hash2_2( uv10 );
		float2 v11 = Hash2_2( uv11 );

		float2 v0 = lerp( v00, v01, f.y );
		float2 v1 = lerp ( v10, v11, f.y );
		float2 v = lerp( v0, v1, f.x );

		return v;
	}

	// Rotates point around 0,0
	float2 Rotate( in float2 p, in float deg )
	{
		float s = sin( deg );
		float c = cos( deg );
		p = mul( Create2x2( s, c, -c, s ), p );
		return p;
	}

]]