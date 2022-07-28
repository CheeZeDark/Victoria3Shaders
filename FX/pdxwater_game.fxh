Includes = {
	"cw/heightmap.fxh"
	"cw/utility.fxh"
	"cw/camera.fxh"
	"cw/shadow.fxh"
	"jomini/jomini_fog.fxh"
	"jomini/jomini_lighting.fxh"
	"jomini/jomini_water.fxh"
	"jomini/jomini_water_default.fxh"
	"jomini/jomini_river.fxh"
}

PixelShader =
{		
	Code
	[[
		#define WavesMaskLargeContrast 0.188f
		#define WavesMaskLargePosition 0.421f
		#define WavesInnerFadeContrast 0.2f
		#define WavesInnerFadePosition -0.05f
		#define WavesFlowFoamContrast 110.0f
		#define WavesFlowFoamPosition 13.77f
		
		#define FoamNoiseContrast 1.5f
		#define FoamNoisePosition -0.1f

		#define ShoreMaskLargeContrast 	0.51f
		#define ShoreMaskLargePosition 	-0.244f
		#define ShoreInnerFadeContrast 	0.105f
		#define ShoreInnerFadePosition 	0.003f
		#define ShoreFlowFoamContrast 0.47f
		#define ShoreFlowFoamPosition 0.08f

		#define CausticsMaskLargeContrast 3.0f
		#define CausticsMaskLargePosition -0.246
		#define CausticsInnerFadeContrast 0.105f
		#define CausticsInnerFadePosition 0.003
	]]

}


PixelShader =
{	
	#//Same data that is being used in the river bottom shader
	TextureSampler BottomDiffuse
	{
		Ref = JominiRiver0
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}

	TextureSampler BottomNormal
	{
		Ref = JominiRiver1
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}

	TextureSampler BottomProperties
	{
		Ref = JominiRiver2
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}

	TextureSampler EnvironmentMap
	{
		Ref = JominiEnvironmentMap
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		Type = "Cube"
	}

	Code
	[[

		float LevelsScanP( float vInValue, float vPosition, float vRange )
		{
			return Levels( vInValue, vPosition - vRange, vPosition + vRange );
		}
		
		float GameCalcFoamFactorWaves( float2 UV01, float2 WorldSpacePosXZ, float Depth, float FlowFoamMask, float3 FlowNormal )
		{
			// Foam calculation
			float FoamMap = PdxTex2D( FoamMapTexture, UV01 ).r;
			float FoamMaskLarge = LevelsScanP( 1.0f - Depth, WavesMaskLargeContrast - WavesMaskLargePosition, WavesMaskLargeContrast + WavesMaskLargePosition );

			float FoamMaskInnerRemove = LevelsScanP( Depth, WavesInnerFadeContrast - WavesInnerFadePosition, WavesInnerFadeContrast + WavesInnerFadePosition );
			FoamMaskLarge *= FoamMaskInnerRemove;

			float3 Foam = PdxTex2D( FoamTexture, WorldSpacePosXZ * _WaterFoamScale + FlowNormal.xz * _WaterFoamDistortFactor ).rgb;

			FlowFoamMask = LevelsScan( FlowFoamMask, ( WavesFlowFoamContrast - WavesFlowFoamPosition ) * 0.01f, ( WavesFlowFoamContrast + WavesFlowFoamPosition ) * 0.01f );
			float3 FoamRamp = PdxTex2DLod0( FoamRampTexture, float2( FoamMaskLarge * FlowFoamMask, 0.5 ) ).rgb;

			// Break apart noise
			float2 NoiseUV = WorldSpacePosXZ * _WaterFoamNoiseScale;
			float FoamNoise1 = PdxTex2D( FoamNoiseTexture, NoiseUV + float2( 1.0f, -1.0f ) * JOMINIWATER_GlobalTime * _WaterFoamNoiseSpeed ).r;
			FoamNoise1 = LevelsScanP( FoamNoise1, FoamNoiseContrast - FoamNoisePosition, FoamNoiseContrast + FoamNoisePosition );
			
			// Large waves
			float FoamResult = saturate( dot( Foam, FoamRamp ) ) * FoamMaskLarge;
			float Strength = 50.0f * _WaterFoamStrength;
			FoamResult = Overlay( FoamResult, FlowFoamMask ) * Strength * FoamNoise1;

			return FoamResult;
		}

		float GameCalcFoamFactorShore( float2 UV01, float2 WorldSpacePosXZ, float Depth, float FlowFoamMask, float3 FlowNormal )
		{
			// Foam calculation
			float FoamMap = PdxTex2D( FoamMapTexture, UV01 ).r;
			float FoamMaskLarge = LevelsScanP( 1.0f - Depth, ShoreMaskLargeContrast - ShoreMaskLargePosition, ShoreMaskLargeContrast + ShoreMaskLargePosition );

			float FoamMaskInnerRemove = LevelsScanP( Depth, ShoreInnerFadeContrast - ShoreInnerFadePosition, ShoreInnerFadeContrast + ShoreInnerFadePosition );
			FoamMaskLarge *= FoamMaskInnerRemove;

			float3 Foam = PdxTex2D( FoamTexture, WorldSpacePosXZ * _WaterFoamScale + FlowNormal.xz * _WaterFoamDistortFactor ).rgb;

			FlowFoamMask = LevelsScan( FlowFoamMask, ShoreFlowFoamContrast - ShoreFlowFoamPosition, ShoreFlowFoamContrast + ShoreFlowFoamPosition );
			float3 FoamRamp = PdxTex2DLod0( FoamRampTexture, float2( FoamMaskLarge * FlowFoamMask, 0.5 ) ).rgb;

			// Break apart noise
			float2 NoiseUV = WorldSpacePosXZ * _WaterFoamNoiseScale;
			float FoamNoise = PdxTex2D( FoamNoiseTexture, NoiseUV + float2( 1.0f, 1.0f ) * JOMINIWATER_GlobalTime * _WaterFoamNoiseSpeed  ).r;
			FoamNoise = LevelsScanP( FoamNoise, FoamNoiseContrast - FoamNoisePosition, FoamNoiseContrast + FoamNoisePosition );

			// Large waves
			float FoamResult = dot( Foam, FoamRamp ) * FoamMaskLarge;
			float Strength = 50.0f * _WaterFoamStrength;
			FoamResult = Overlay( FoamResult, FlowFoamMask ) * Strength * FoamNoise;

			return saturate( FoamResult );
		}

		float GameCalcFoamFactorCaustics( float2 UV01, float2 WorldSpacePosXZ, float Depth, float FlowFoamMask, float3 FlowNormal )
		{
			// Foam calculation
			float FoamMap = PdxTex2D( FoamMapTexture, UV01 ).r;
			float FoamMaskLarge = LevelsScanP( 1.0f - Depth, CausticsMaskLargeContrast - CausticsMaskLargePosition, CausticsMaskLargeContrast + CausticsMaskLargePosition );

			float FoamMaskInnerRemove = LevelsScanP( Depth, CausticsInnerFadeContrast - CausticsInnerFadePosition, CausticsInnerFadeContrast + CausticsInnerFadePosition );
			FoamMaskLarge *= FoamMaskInnerRemove;

			float3 Foam = PdxTex2D( FoamTexture, WorldSpacePosXZ * _WaterFoamScale + FlowNormal.xz * _WaterFoamDistortFactor ).rgb;

			float3 FoamRamp = PdxTex2DLod0( FoamRampTexture, float2( FoamMaskLarge, 0.5 ) ).rgb;

			// Break apart noise
			float2 NoiseUV = WorldSpacePosXZ * _WaterFoamNoiseScale * 0.5f;
			float FoamNoise = PdxTex2D( FoamNoiseTexture, NoiseUV + float2( 1.0f, 1.0f ) * JOMINIWATER_GlobalTime * _WaterFoamNoiseSpeed  ).r;

			// Large waves
			float FoamResult = dot( Foam, FoamRamp ) * FoamMaskLarge;
			float Strength = 100.0f * _WaterFoamStrength;
			FoamResult = FoamResult * Strength * FoamNoise;

			return saturate( FoamResult );
		}

		float3 GameCalcReflection( float3 Normal, float3 ToCameraDir )
		{
			float3 ReflectionNormal = Normal;
			ReflectionNormal.y += _WaterReflectionNormalFlatten; // TODO, decay with distance?
			ReflectionNormal = normalize( ReflectionNormal );
			float3 ReflectionVector = reflect( -ToCameraDir, ReflectionNormal );
			float3 Reflection = PdxTexCube( ReflectionCubeMap, ReflectionVector ).rgb * _WaterCubemapIntensity;
			
			return Reflection;
		}

		float4 GameCalcWater( in SWaterParameters Input )
		{
			float4 WaterColorAndSpec = PdxTex2D( WaterColorTexture, Input._WorldUV );
			float GlossMap = WaterColorAndSpec.a;

			float3 ToCamera = CameraPosition.xyz - Input._WorldSpacePos;
			float3 ToCameraDir = normalize( ToCamera );

			// Normals
			float2 UVCoord = Input._WorldSpacePos.xz * float2( 1.0f, -1.0f ) * Input._NoiseScale;
			float3 NormalMap1 = SampleNormalMapTexture( AmbientNormalTexture, UVCoord, _WaterWave1Scale, _WaterWave1Rotation, JOMINIWATER_GlobalTime * _WaterWave1Speed * Input._WaveSpeedScale, _WaterWave1NormalFlatten * Input._WaveNoiseFlattenMult );
			float3 NormalMap2 = SampleNormalMapTexture( AmbientNormalTexture, UVCoord, _WaterWave2Scale, _WaterWave2Rotation, JOMINIWATER_GlobalTime * _WaterWave2Speed * Input._WaveSpeedScale, _WaterWave2NormalFlatten * Input._WaveNoiseFlattenMult );
			float3 NormalMap3 = SampleNormalMapTexture( AmbientNormalTexture, UVCoord, _WaterWave3Scale, _WaterWave3Rotation, JOMINIWATER_GlobalTime * _WaterWave3Speed * Input._WaveSpeedScale, _WaterWave3NormalFlatten * Input._WaveNoiseFlattenMult );

			float3 Normal = NormalMap1 + NormalMap2 + NormalMap3 + Input._FlowNormal;
			#ifdef WATER_LOCAL_SPACE_NORMALS
				float3x3 TBN = Create3x3( Input._Tangent, Input._Bitangent, Input._Normal );
				Normal = normalize( mul( Normal.xzy, TBN ) );
			#else
				Normal = normalize( Normal );
			#endif

			// Foam
			float FoamFactor = GameCalcFoamFactorWaves( Input._WorldUV, Input._WorldSpacePos.xz, Input._Depth, Input._FlowFoamMask, Input._FlowNormal );
			FoamFactor += GameCalcFoamFactorShore( Input._WorldUV, Input._WorldSpacePos.xz, Input._Depth, Input._FlowFoamMask, Input._FlowNormal );
			FoamFactor += GameCalcFoamFactorCaustics( Input._WorldUV, Input._WorldSpacePos.xz, Input._Depth, Input._FlowFoamMask, Input._FlowNormal );
			
			// Prelight color
			float Facing = 1.0f - max( dot( Normal, ToCameraDir ), 0.0f );
			float3 WaterDiffuse = lerp( _WaterColorDeep, _WaterColorShallow, Facing );
			WaterDiffuse *= _WaterDiffuseMultiplier;
			
			// Light			
			SWaterLightingProperties lightingProperties;
			lightingProperties._WorldSpacePos = Input._WorldSpacePos;
			lightingProperties._ToCameraDir = ToCameraDir;
			lightingProperties._Normal = Normal;
			lightingProperties._Diffuse = WaterDiffuse + FoamFactor;
			lightingProperties._Glossiness = lerp( _WaterGlossBase, GlossMap, _WaterZoomedInZoomedOutFactor );
			lightingProperties._SpecularColor = vec3( _WaterSpecular );
			lightingProperties._NonLinearGlossiness = GetNonLinearGlossiness( lightingProperties._Glossiness ) * _WaterGlossScale;
			float3 DiffuseLight = vec3( 0.0f );
			float3 SpecularLight = vec3( 0.0f );
			
			CalculateSunLight( lightingProperties, 1.0f, _WaterToSunDir, DiffuseLight, SpecularLight );
			float3 FinalColor = ComposeLight( lightingProperties, 1.0f, _WaterToSunDir, DiffuseLight, SpecularLight * _WaterSpecularFactor );

			// Refraction
			float3 Refraction = CalcRefraction( Input._WorldSpacePos, Normal, Input._ScreenSpacePos.xy, WaterColorAndSpec.rgb, Input._Depth );

			float Depth = Input._Depth;
			#if defined( RIVER ) && defined( JOMINI_REFRACTION_ENABLED ) 
				float4 RefractionSample = PdxTex2DLod0( RefractionTexture, Input._ScreenSpacePos.xy / _ScreenResolution );
				float3 RefractionWorldSpacePos = DecompressWorldSpace( Input._WorldSpacePos, RefractionSample.a );
				float RefractionDepth = Input._WorldSpacePos.y - RefractionWorldSpacePos.y;
				Depth = min( Depth, RefractionDepth );
				float WaterFade = 1.0f - saturate( (_WaterFoamShoreMaskDepth - Depth) * _WaterFoamShoreMaskSharpness ) ;
			#else
				float WaterFade = 1.0f - saturate( (_WaterFadeShoreMaskDepth - Depth) * _WaterFadeShoreMaskSharpness ) ;
			#endif

			FinalColor *= WaterFade;
			
			// Cubemap reflection
			float3 Reflection = CalcReflection( Normal, ToCameraDir );
			float FresnelFactor = Fresnel( abs( dot( lightingProperties._ToCameraDir, Normal ) ), _WaterFresnelBias, _WaterFresnelPow ) * WaterFade;
			FinalColor += lerp( Refraction, Reflection, FresnelFactor );
			
			// Fade
			#ifdef JOMINIWATER_BORDER_LERP
				float ExtraFade = 1.0f - ( Input._WorldUV.x - 1.0f ) / JOMINIWATER_BorderLerpSize;
				WaterFade *= ExtraFade;
			#endif
			
			return float4( FinalColor, WaterFade );
		}

		
		float4 GameCalcRiver( in VS_OUTPUT_RIVER Input )
		{			
			float Depth = CalcDepth( Input.UV );
			
			SWaterParameters Params;
			Params._ScreenSpacePos = Input.Position;
			Params._WorldSpacePos = Input.WorldSpacePos;
			Params._WorldUV = Input.WorldSpacePos.xz / MapSize;
			Params._WorldUV.y = 1.0f - Params._WorldUV.y;
			Params._Depth = Depth * Input.Width + 0.1f;
			Params._NoiseScale = _NoiseScale;
			Params._WaveSpeedScale = _NoiseSpeed;
			Params._WaveNoiseFlattenMult = _FlattenMult;
			
			// Flow Movement
			float2 FlowNormalUV = Input.UV.yx * float2( 1.0f, -1.0f );
			FlowNormalUV *= float2( Input.Width, 1.0f ) * _FlowNormalUvScale;
			FlowNormalUV.y += GlobalTime * _FlowNormalSpeed;
			float4 FlowNormalSample = PdxTex2D( FlowNormalTexture, FlowNormalUV );
			
			float3 FlowNormal = UnpackNormal( FlowNormalSample ).xzy;
			FlowNormal.y *= _WaterFlowNormalFlatten * _FlattenMult * saturate( dot( Input.Normal, float3( 0.0f, 1.0f, 0.0f ) ) );
			Params._FlowNormal = normalize( FlowNormal );
			Params._FlowFoamMask = FlowNormalSample.a * _RiverFoamFactor;

			// Water color
			float4 Color = GameCalcWater( Params );
			
			// Sampled bottom texture
			float2 BottomUV = float2( Input.UV.x * _TextureUvScale, Input.UV.y );
			float4 BottomDiffuseSample = PdxTex2D( BottomDiffuse, BottomUV );
			
			// Ocean and river connection fade
			#if defined( JOMINI_REFRACTION_ENABLED )
				Color.a = BottomDiffuseSample.a;
				Color.a *= Input.Transparency * saturate( ( Input.DistanceToMain - 0.1f ) * 5.0f );
			#else
				// Hack to use river bottom textures when refraction is disabled
				float4 BottomPropertiesSample = PdxTex2D( BottomProperties, BottomUV );
				float4 BottomNormalSample = PdxTex2D( BottomNormal, BottomUV );
				float3 BottomNormalUnpacked = UnpackRRxGNormal( BottomNormalSample );
				
				// Normals
				float3 Normal = normalize( Input.Normal );
				float3 Tangent = normalize( Input.Tangent );
				float3 Bitangent = normalize( cross( Normal, Tangent ) );

				float3x3 TBN = Create3x3( normalize( Tangent ), normalize( Bitangent ), Normal );
				BottomNormalUnpacked = normalize( mul( BottomNormalUnpacked, TBN ) );
				
				// Light
				float4 ShadowProj = mul( ShadowMapTextureMatrix, float4( Input.WorldSpacePos, 1.0 ) );
				float ShadowTerm = CalculateShadow( ShadowProj, ShadowMap );
				SMaterialProperties MaterialProps = GetMaterialProperties( BottomDiffuseSample.rgb, BottomNormalUnpacked, BottomPropertiesSample.a, BottomPropertiesSample.g, BottomPropertiesSample.b );
				SLightingProperties LightingProps = GetSunLightingProperties( Input.WorldSpacePos, ShadowTerm );
				BottomDiffuseSample.rgb = CalculateSunLighting( MaterialProps, LightingProps, EnvironmentMap );
				
				// Bottom Color
				Color.rgb = lerp( Color.rgb, BottomDiffuseSample.rgb, saturate( pow( BottomNormalSample.b, 3.0f ) ) );
				Color.a = BottomDiffuseSample.a;
				Color.a *= Input.Transparency * saturate( ( Input.DistanceToMain - 0.1f ) * 5.0f );
			#endif

			// Edge fade
			float EdgeFade1 = smoothstep( 0.0f, _BankFade, Input.UV.y );
			float EdgeFade2 = smoothstep( 0.0f, _BankFade, 1.0f - Input.UV.y );
			Color.a *= EdgeFade1 * EdgeFade2;

			return Color;
		}

	]]
}