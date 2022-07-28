Includes = {
	#"fog_of_war_impl.fxh"
	"jomini/jomini.fxh"
	"jomini/jomini_fog_of_war.fxh"
	"cw/utility.fxh"
}

PixelShader = {
	ConstantBuffer( GameFogOfWar )
	{
		float4 FoWShadowColor;
		float4 FoWCloudsColor;
		float4 FoWCloudsColorSecondary;

		float FoWCloudsColorGradientMin;
		float FoWCloudsColorGradientMax;

		float FoWCloudHeight;

		float FoWShadowMult;
		float FoWShadowTexStart;
		float FoWShadowTexStop;

		float FoWShadowAlphaStart;
		float FoWShadowAlphaStop;
		float FoWCloudsAlphaStart;
		float FoWCloudsAlphaStop;

		float FoWMasterStart;
		float FoWMasterStop;
		int FoWMasterUVTiling;
		float FoWMasterUVRotation;
		float2 FoWMasterUVScale;
		float2 FoWMasterUVSpeed;

		float FoWLayer1Min;
		float FoWLayer1Max;
		int FoWLayer1Tiling;

		float FoWLayer2Min;
		float FoWLayer2Max;
		float FoWLayer2Balance;
		int FoWLayer2Tiling;

		float FoWLayer3Min;
		float FoWLayer3Max;
		float FoWLayer3Balance;
		int FoWLayer3Tiling;

		float FoWShowAlphaMask;

		float2 FoWLayer1Speed;
		float2 FoWLayer2Speed;
		float2 FoWLayer3Speed;

	}
	TextureSampler FogOfWarAlpha
	{
		Ref = JominiFogOfWar
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler FogOfWarNoise
	{
		Ref = GameFogOfWarNoise
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	Code [[	
		float SampleFowNoiseLowSpec( in float3 Coordinate ) 
		{		
				// Uv tiling
				float2 MasterUVTiling = FoWMasterUVTiling * Coordinate.xz * InverseWorldSize;
				MasterUVTiling.x *= FoWMasterUVScale.x;
				MasterUVTiling.y *= FoWMasterUVScale.y;
				float2 UV = MasterUVTiling * FoWLayer1Tiling;

				// Animation
				float2 AnimUV = float2(FoWLayer1Speed.x * FoWMasterUVSpeed.x, FoWLayer1Speed.y * FoWMasterUVSpeed.y) * FogOfWarTime * 0.01f;
				UV += AnimUV * FoWMasterUVScale;

				// Layer sample
				float Layer1 = PdxTex2D( FogOfWarNoise, UV ).r;
				Layer1 = smoothstep( FoWLayer1Min, FoWLayer1Max, Layer1 );

				// Detail noise blending
				float Cloud = smoothstep( FoWLayer1Min, FoWLayer1Max, Layer1 );
				return Cloud;
		}

		float SampleFowNoise( in float3 Coordinate ) 
		{		

				// Uv tiling and animation
				float2 MasterUVTiling = FoWMasterUVTiling * Coordinate.xz * InverseWorldSize;

				// Scale
				MasterUVTiling.x *= FoWMasterUVScale.x;
				MasterUVTiling.y *= FoWMasterUVScale.y;

				float2 UV = MasterUVTiling * FoWLayer1Tiling;
				float2 UV2 = MasterUVTiling * FoWLayer2Tiling;
				float2 UV3 = MasterUVTiling * FoWLayer3Tiling;

				// Animation
				float2 AnimUV = float2(FoWLayer1Speed.x * FoWMasterUVSpeed.x, FoWLayer1Speed.y * FoWMasterUVSpeed.y) * FogOfWarTime * 0.01f;
				float2 AnimUV2 = float2(FoWLayer2Speed.x * FoWMasterUVSpeed.x, FoWLayer2Speed.y * FoWMasterUVSpeed.y) * FogOfWarTime * 0.01f;
				float2 AnimUV3 = float2(FoWLayer3Speed.x * FoWMasterUVSpeed.x, FoWLayer3Speed.y * FoWMasterUVSpeed.y) * FogOfWarTime * 0.01f;
				UV += AnimUV * FoWMasterUVScale;
				UV2 += AnimUV2 * FoWMasterUVScale;
				UV3 +=AnimUV3 * FoWMasterUVScale;

				// Layers sample
				float Layer1 = PdxTex2D( FogOfWarNoise, UV ).r;
				float Layer2 = PdxTex2D( FogOfWarNoise, UV2 ).r;
				float Layer3 = PdxTex2D( FogOfWarNoise, UV3 ).r;

				// Layers min/max adjustment
				Layer1 = smoothstep( FoWLayer1Min, FoWLayer1Max, Layer1 );
				Layer2 = smoothstep( FoWLayer2Min, FoWLayer2Max, Layer2 );
				Layer3 = smoothstep( FoWLayer3Min, FoWLayer3Max, Layer3 );

				// Detail noise blending
				float Cloud = Overlay(Layer1, Layer2, FoWLayer2Balance );
				Cloud = Overlay(Cloud, Layer3, FoWLayer3Balance );

				return Cloud;
		}

		float3 GameApplyFogOfWar( in float3 Color, in float3 Coordinate, PdxTextureSampler2D FogOfWarAlphaMask )
		{
			#ifdef PDX_DEBUG_FOW_OFF
				return Color;
			#endif

			#ifdef JOMINI_DISABLE_FOG_OF_WAR
				return Color;
			#endif
			
			float Alpha = PdxTex2D( FogOfWarAlphaMask, Coordinate.xz * InverseWorldSize ).r;
			#ifdef PDX_DEBUG_FOW_MASK
				return float4( Alpha.rrr, 1.0f );
			#endif
			Alpha = max( Alpha, FogOfWarAlphaMin );

			if( FoWShowAlphaMask > 0.0f ) {
				return vec3( 1.0f - Alpha );
			}

			float InvAlpha = 1.0f - Alpha;
			float MinAlpha = 1.0f - FogOfWarAlphaMin;
			float ShadowAlpha = smoothstep( FoWShadowAlphaStart, FoWShadowAlphaStop, InvAlpha ) * FoWShadowColor.a * MinAlpha;
			float CloudsAlpha = smoothstep( FoWCloudsAlphaStart, FoWCloudsAlphaStop, InvAlpha ) * FoWCloudsColor.a * MinAlpha;

			// Paralax offset
			float3 ToCam = normalize( CameraPosition - Coordinate );
			float ParalaxDist = ( FoWCloudHeight - Coordinate.y ) / ToCam.y;
			float3 ParalaxCoord = Coordinate + ToCam * ParalaxDist;

			// Sun shadow offset
			float ShadowCordDist = ( FoWCloudHeight - Coordinate.y ) / ToSunDir.y;
			Coordinate =  Coordinate + ToSunDir * ShadowCordDist;

			// Cloud and cloud shadow texture
			#ifdef LOW_QUALITY_SHADERS
				float CloudTex = smoothstep( FoWMasterStart, FoWMasterStop, SampleFowNoiseLowSpec( ParalaxCoord ) );
				float ShadowTex = smoothstep( FoWShadowTexStart, FoWShadowTexStop, SampleFowNoiseLowSpec( Coordinate ) );
			#else
				float CloudTex = smoothstep( FoWMasterStart, FoWMasterStop, SampleFowNoise( ParalaxCoord ) );
				float ShadowTex = smoothstep( FoWShadowTexStart, FoWShadowTexStop, SampleFowNoise( Coordinate ) );
			#endif

			// Apply Fog Of War Shadow
			float3 FinalColor = lerp( Color, FoWShadowColor.rgb, FoWShadowMult * ShadowAlpha ); 

			// Apply Cloud Shadows
			FinalColor = lerp( FinalColor, FoWShadowColor.rgb, FoWShadowMult * ShadowTex );

			float GradientControl = smoothstep( FoWCloudsColorGradientMin, FoWCloudsColorGradientMax, CloudTex );
			float3 CloudsColor = lerp( FoWCloudsColorSecondary.rgb, FoWCloudsColor.rgb, GradientControl );
			FinalColor = lerp( FinalColor, CloudsColor, CloudTex * CloudsAlpha );

			return FinalColor;
		}

		float3 GameApplyFogOfWarMultiSampled( in float3 Color, in float3 Coordinate, PdxTextureSampler2D FogOfWarAlphaMask )
		{
			#ifdef PDX_DEBUG_FOW_OFF
			return Color;
			#endif
			
			float Alpha = GetFogOfWarAlphaMultiSampled( Coordinate, FogOfWarAlphaMask );
			#ifdef PDX_DEBUG_FOW_MASK
			return float4( Alpha.rrr, 1.0f );
			#endif
			
			if( FoWShowAlphaMask > 0.0f ) {
				return vec3( 1.0f - Alpha );
			}
			return FogOfWarBlend( Color, Alpha );
		}
		
		// Post process
		float4 GameApplyFogOfWar( in float3 WorldSpacePos, PdxTextureSampler2D FogOfWarAlphaMask )
		{
			#ifdef PDX_DEBUG_FOW_OFF
			return vec4(0);
			#endif
			
			float Alpha = GetFogOfWarAlpha( WorldSpacePos, FogOfWarAlphaMask );
			
			#ifdef PDX_DEBUG_FOW_MASK
			return float4( Alpha.rrr, 1.0f );
			#endif
			
			return FOG_OF_WAR_BLEND_FUNCTION( Alpha );
		}
		
		#undef ApplyFogOfWar
		#undef ApplyFogOfWarMultiSampled		
		#define ApplyFogOfWar GameApplyFogOfWar	
		#define ApplyFogOfWarMultiSampled GameApplyFogOfWarMultiSampled
	]]
}
