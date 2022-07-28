Includes = {
	"cw/camera.fxh"
	"jomini/jomini_flat_border.fxh"
	"sharedconstants.fxh"
	"distance_fog.fxh"
	"fog_of_war.fxh"
	"ssao_struct.fxh"
}

VertexStruct VS_OUTPUT_PDX_BORDER
{
	float4 Position			: PDX_POSITION;
	float3 WorldSpacePos	: TEXCOORD0;
	float2 UV				: TEXCOORD1;
};


VertexShader =
{
	MainCode VertexShader
	{
		Input = "VS_INPUT_PDX_BORDER"
		Output = "VS_OUTPUT_PDX_BORDER"
		Code
		[[
			PDX_MAIN
			{
				VS_OUTPUT_PDX_BORDER Out;

				float3 position = Input.Position.xyz;
				position.y = lerp( position.y, FlatMapHeight, FlatMapLerp );
				position.y += _HeightOffset;

				Out.WorldSpacePos = position;
				Out.Position = FixProjectionAndMul( ViewProjectionMatrix, float4( position, 1.0 ) );
				Out.UV = Input.UV;

				return Out;
			}
		]]
	}
}

PixelShader =
{
	TextureSampler BorderTexture
	{
		Ref = PdxTexture0
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler CountryColors
	{
		Ref = CountryColors
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}

	MainCode BorderPs
	{
		Input = "VS_OUTPUT_PDX_BORDER"
		Output = "PS_COLOR_SSAO"
		Code
		[[
			PDX_MAIN
			{
				PS_COLOR_SSAO Out;

				float4 Diffuse = PdxTex2D( BorderTexture, Input.UV );

				#ifdef COUNTRY_COLOR
					float4 CountryColor = PdxTex2DLoad0( CountryColors, int2( _UserId, 0 ) );
					Diffuse.rgb *= CountryColor.rgb;
					Diffuse.rgb *= 1.0f - FlatMapLerp;
					Diffuse.a = lerp( Diffuse.a, 0.5f, FlatMapLerp );
				#endif

				#ifdef IMPASSABLE_BORDER
					Diffuse.rgb *= ImpassableTerrainColor.rgb;

					float FadeStart = ( ImpassableTerrainFadeStart - ImpassableTerrainFadeEnd );
					float CloseZoomBlend = FadeStart - CameraPosition.y + ( ImpassableTerrainFadeEnd );
					CloseZoomBlend = smoothstep( FadeStart, 0.0f, CloseZoomBlend );
					Diffuse.a *= CloseZoomBlend;
				#endif

				if( FlatMapLerp < 1.0f )
				{
					float3 Unfogged = Diffuse.rgb;
					Diffuse.rgb = ApplyFogOfWar( Diffuse.rgb, Input.WorldSpacePos, FogOfWarAlpha );
					Diffuse.rgb = GameApplyDistanceFog( Diffuse.rgb, Input.WorldSpacePos );
					Diffuse.rgb = lerp( Diffuse.rgb, Unfogged, FlatMapLerp );
				}
				Diffuse.a *= _Alpha;

				// Output
				Out.Color = Diffuse;

				// Process to mask out SSAO where borders become opaque, using SSAO color
				Out.SSAOColor = float4( 1.0f, 1.0f, 1.0f, Diffuse.a );

				return Out;
			}
		]]
	}

	TextureSampler BorderTexture0
	{
		Ref = JominiVerticalBordersMask0
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}

	MainCode FlatWarBorderPs
	{
		Input = "VS_OUTPUT_PDX_BORDER"
		Output = "PS_COLOR_SSAO"
		Code
		[[

			#define ANIMATION_SPEED float2( 3.0, 1.0f )
			#define UV_TILING 8

			#define NOISE_MASK_POSITION 1.3f
			#define NOISE_MASK_CONTRAST 2.3f

			#define COLOR_1 float3( 255.0f, 0.0f, 0.0f ) / 255.0f
			#define COLOR_2 float3( 40.0f, 40.0f, 0.0f ) / 255.0f
			#define COLOR_INTENSITY 30.0f

			#define FADE_DISTANCE 0.7
			#define FADE_SHARPNESS 8

			PDX_MAIN
			{
				PS_COLOR_SSAO Out;

				float4 Diffuse = vec4( 1.0f );
				Diffuse.rgb = float3( 0.5f, 0.0f, 0.0f );

				float2 WorldUV = Input.WorldSpacePos.xz;
				float2 AnimUVs = float2( WorldUV.x, -WorldUV.y ) - GlobalTime * ANIMATION_SPEED;
				AnimUVs = AnimUVs * UV_TILING * 0.001f;

				// Noise
				float NoiseLayer = PdxTex2D( BorderTexture, AnimUVs ).a;
				NoiseLayer = saturate( LevelsScan( NoiseLayer, NOISE_MASK_POSITION, NOISE_MASK_CONTRAST ) );

				// Color
				float4 BottomLayer = float4( COLOR_1, 1.0f );
				float4 Color1Layer = float4( COLOR_2, NoiseLayer );
				BottomLayer.rgb *= COLOR_INTENSITY;
				Color1Layer.rgb *= COLOR_INTENSITY;

				Diffuse.rgb = AlphaBlend_AOverB( Color1Layer, BottomLayer );

				// Alpha
				float FadeRight = Input.UV.y;
				FadeRight = saturate( ( FADE_DISTANCE - FadeRight) * FADE_SHARPNESS );
				float FadeLeft = 1.0f - Input.UV.y;
				FadeLeft = saturate( ( FADE_DISTANCE - FadeLeft ) * FADE_SHARPNESS );
				Diffuse.a *= FadeRight * FadeLeft * FlatMapLerp ;

				// Output
				Out.Color = Diffuse;

				// Process to mask out SSAO where borders become opaque, using SSAO color
				Out.SSAOColor = float4( 1.0f, 1.0f, 1.0f, Diffuse.a );

				return Out;
			}
		]]
	}
}


BlendState BlendState
{
	BlendEnable = yes
	SourceBlend = "SRC_ALPHA"
	DestBlend = "INV_SRC_ALPHA"
	WriteMask = "RED|GREEN|BLUE"
}

RasterizerState RasterizerState
{
	DepthBias = 0
	SlopeScaleDepthBias = 0
}

DepthStencilState DepthStencilState
{
	#// Always render on top
	DepthEnable = no
	DepthWriteEnable = no
}

Effect DefaultBorder
{
	VertexShader = "VertexShader"
	PixelShader = "BorderPs"
}
Effect CountryBorder
{
	VertexShader = "VertexShader"
	PixelShader = "BorderPs"
	Defines = { "COUNTRY_COLOR" }
}
Effect ImpassableBorder
{
	VertexShader = "VertexShader"
	PixelShader = "BorderPs"
	Defines = { "IMPASSABLE_BORDER" }
}
Effect FlatWarBorder
{
	VertexShader = "VertexShader"
	PixelShader = "FlatWarBorderPs"
	Defines = { "FLAT_WAR_BORDER" }
}
