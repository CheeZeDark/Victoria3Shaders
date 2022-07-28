Includes = {
	"cw/utility.fxh"
	"cw/pdxterrain.fxh"
	"cw/curve.fxh"
	"cw/camera.fxh"
	"cw/lighting.fxh"
	"sharedconstants.fxh"
}


PixelShader =
{
	ConstantBuffer( DevastationConstants )
	{
		float2 DevastationBezierPoint1;
		float2 DevastationBezierPoint2;

		int DevastationTexIndex;
		int DevastationTexIndexOffset;

		int DevastationNoiseTiling;
		int DevastationTextureTiling;

		float DevastationHue;
		float DevastationSaturation;
		float DevastationValue;

		float DevastationTreeHue;
		float DevastationTreeSaturation;
		float DevastationTreeValue;

		float DevastationAreaPosition;
		float DevastationAreaContrast;
		float DevastationAreaMax;

		float DevastationHeightWeight;
		float DevastationHeightContrast;

		float DevastationExclusionMaskMin;
		float DevastationExclusionMaskMax;

		float DevastationTreeAlphaReduce;

		float DevastationForceAdd;
	};

	ConstantBuffer( PollutionConstants )
	{
		float3 IridescenseRimlightDirection;
		float _Padding1;
		float2 PollutionBezierPoint1;
		float2 PollutionBezierPoint2;

		int PollutionTexIndex;
		int PollutionTexIndexOffset;

		int PollutionNoiseTiling;
		int PollutionTextureTiling;

		float PollutionHue;
		float PollutionSaturation;
		float PollutionValue;

		float PollutionTreeHue;
		float PollutionTreeSaturation;
		float PollutionTreeValue;

		float PollutionAreaPosition;
		float PollutionAreaContrast;
		float PollutionAreaMax;

		float PollutionHeightWeight;
		float PollutionHeightContrast;

		float PollutionExclusionMaskMin;
		float PollutionExclusionMaskMax;

		float PollutionTreeAlphaReduce;

		float PollutionForceAdd;

		float IridescenseOpacity;
		float IridescenseNoiseTiling;
		float IridescensePosition;
		float IridescenseContrast;
		float IridescenseRoughness;
		float IridescenseRed;
		float IridescenseGreen;
		float IridescenseBlue;

		float IridescenseRimlightStrength;

		float IridescenseThicknessMin;			//	Minimum thickness of the film, in nm
		float IridescenseThicknessmax;			//	Maximum thickness of the film, in nm
		float IridescenseMediumn;				//	Approximate refractive index of air  
		float IridescenseFilmn;					//	Approximate refractive index of water
		float Iridescenseinternaln;				//	Approximate refractive index of the lower material

	};

	#Devastation in R
	#Pollution in G
	#Exclusion mask in B
	#Noise in A
	TextureSampler DevastationPollution
	{
		Ref = DevastationPollutionMask
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
		Code
		[[	

		float2 CalcHeightBlendFactors( float2 MaterialHeights, float2 MaterialFactors, float BlendRange )
		{
			float2 Mat = MaterialHeights + MaterialFactors;
			float BlendStart = max( Mat.x, Mat.y ) - max( BlendRange, 0.01f );
			
			float2 MatBlend = max( Mat - vec2( BlendStart ), vec2( 0.0f ) );
			
			float Epsilon = 0.00001f;
			return float2( MatBlend ) / ( dot( MatBlend, vec2( 1.0f ) ) + Epsilon );
		}

		/* Amplitude reflection coefficient (s-polarized) */
		float Rs(float n1, float n2, float cosI, float cosT) 
		{
			return ( n1 * cosI - n2 * cosT ) / ( n1 * cosI + n2 * cosT );
		}
		
		/* Amplitude reflection coefficient (p-polarized) */
		float Rp(float n1, float n2, float cosI, float cosT) 
		{
			return ( n2 * cosI - n1 * cosT ) / ( n1 * cosT + n2 * cosI );
		}
		
		/* Amplitude transmission coefficient (s-polarized) */
		float Ts( float n1, float n2, float cosI, float cosT ) 
		{
			return 2 * n1 * cosI / ( n1 * cosI + n2 * cosT );
		}
		
		/* Amplitude transmission coefficient (p-polarized) */
		float Tp( float n1, float n2, float cosI, float cosT ) 
		{
			return 2 * n1 * cosI / ( n1 * cosT + n2 * cosI );
		}
		
		// cosI is the cosine of the incident angle, that is, cos0 = dot(view angle, normal)
		// lambda is the wavelength of the incident light (e.g. lambda = 510 for green)
		// From http://www.gamedev.net/page/resources/_/technical/graphics-programming-and-theory/thin-film-interference-for-computer-graphics-r2962
		float ThinFilmReflectance(float cos0, float lambda, float thickness, float n0, float n1, float n2 ) 
		{
			
			// Compute the phase change term (constant)
			float d10 = ( n1 > n0 ) ? 0.0f : PI;
			float d12 = ( n1 > n2 ) ? 0.0f : PI;
			float delta = d10 + d12;
			
			// Compute cos1, the cosine of the reflected angle
			float sin1 = pow( n0 / n1, 2.0f ) * (1.0f - pow( cos0, 2.0f ) );
			if ( sin1 > 1 ) return 1.0f; // total internal reflection
			float cos1 = sqrt( 1.0f - sin1 );
			
			// Compute cos2, the cosine of the final transmitted angle, i.e. cos(theta_2)
			float sin2 = pow( n0 / n2, 2.0f ) * ( 1.0f - pow( cos0, 2.0f ) );
			if ( sin2 > 1.0f )
			{
				return 1.0f; // Total internal reflection
			} 
				
			float cos2 = sqrt( 1.0f - sin2 );
			
			// Get the reflection transmission amplitude Fresnel coefficients
			float alpha_s = Rs( n1, n0, cos1, cos0 ) * Rs( n1, n2, cos1, cos2 ); // rho_10 * rho_12 (s-polarized)
			float alpha_p = Rp( n1, n0, cos1, cos0 ) * Rp( n1, n2, cos1, cos2 ); // rho_10 * rho_12 (p-polarized)
			
			float beta_s = Ts( n0, n1, cos0, cos1 ) * Ts( n1, n2, cos1, cos2 ); // tau_01 * tau_12 (s-polarized)
			float beta_p = Tp( n0, n1, cos0, cos1 ) * Tp( n1, n2, cos1, cos2 ); // tau_01 * tau_12 (p-polarized)
				
			// Compute the phase term (phi)
			float phi = ( 2.0f * PI / lambda ) * ( 2.0f * n1 * thickness * cos1 ) + delta;
				
			// Evaluate the transmitted intensity for the two possible polarizations
			float ts = pow( beta_s, 2.0f ) / ( pow( alpha_s, 2.0f ) - 2.0f * alpha_s * cos( phi ) + 1.0f );
			float tp = pow( beta_p, 2.0f ) / ( pow( alpha_p, 2.0f ) - 2.0f * alpha_p * cos( phi ) + 1.0f );
			
			// Take into account conservation of energy for transmission
			float beamRatio = ( n2 * cos2 ) / ( n0 * cos0 );
			
			// Calculate the average transmitted intensity
			float t = beamRatio * ( ts + tp ) / 2;
			
			// Derive the reflected intensity
			return saturate( 1 - t );
		}


		float GetDevastation( float2 MapCoordinates )
		{
			float Devastation = PdxTex2D( DevastationPollution, MapCoordinates ).r;
			Devastation += DevastationForceAdd;
			Devastation = CubicBezier( Devastation, DevastationBezierPoint1, DevastationBezierPoint2 );

			if( Devastation <= 0.01f ) 
			{
				return 0.0f;
			}

			float2 DevastationCoords = float2( MapCoordinates.x * 2.0f, MapCoordinates.y ) * DevastationNoiseTiling;
			float Noise = 1.0f - PdxTex2D( DevastationPollution, DevastationCoords ).a;
			Noise = lerp(0.0f, Noise, Devastation);
			Noise = LevelsScan( Noise, DevastationAreaPosition, DevastationAreaContrast);
			return Noise;
		}
		float GetPollution( float2 MapCoordinates )
		{
			float Pollution = PdxTex2D( DevastationPollution, MapCoordinates ).g;
			Pollution += PollutionForceAdd;
			Pollution = CubicBezier( Pollution, PollutionBezierPoint1, PollutionBezierPoint2 );

			if( Pollution <= 0.01f ) 
			{
				return 0.0f;
			}

			float2 PollutionCoords = float2( MapCoordinates.x * 2.0f, MapCoordinates.y ) * PollutionNoiseTiling;
			float Noise = 1.0f - PdxTex2D( DevastationPollution, PollutionCoords ).a;
			Noise = lerp(0.0f, Noise, Pollution);
			Noise = LevelsScan( Noise, PollutionAreaPosition, PollutionAreaContrast);
			return Noise;
		}

		void ApplyDevastationTrees( inout float4 Diffuse, float2 MapCoordinates )
		{
			// Devastation area
			float Devastation = GetDevastation( MapCoordinates ) * 2.0f;
			if( Devastation <= 0.01f ) 
			{
				return;
			}

			// Diffuse coloration
			float3 DevastatedDiffuse = RGBtoHSV( Diffuse.rgb );
			DevastatedDiffuse.x += DevastationTreeHue;				// Hue
			DevastatedDiffuse.y *= DevastationTreeSaturation;		// Saturation
			DevastatedDiffuse.z *= DevastationTreeValue;			// Value
			DevastatedDiffuse = HSVtoRGB( DevastatedDiffuse );

			// Alpha
			float DevastatedAlpha = smoothstep( DevastationTreeAlphaReduce, 1.0f, Diffuse.a );

			// Return
			Diffuse.a = lerp( Diffuse.a, DevastatedAlpha, Devastation );
			Diffuse.rgb = lerp( Diffuse.rgb, DevastatedDiffuse, Devastation );
		}
		void ApplyPollutionTrees( inout float4 Diffuse, float2 MapCoordinates )
		{
			// Pollution area
			float Pollution = GetPollution( MapCoordinates ) * 2.0f;
			if( Pollution <= 0.01f ) 
			{
				return;
			}

			// Diffuse coloration
			float3 PollutedDiffuse = RGBtoHSV( Diffuse.rgb );
			PollutedDiffuse.x += PollutionTreeHue;				// Hue
			PollutedDiffuse.y *= PollutionTreeSaturation;		// Saturation
			PollutedDiffuse.z *= PollutionTreeValue;			// Value
			PollutedDiffuse = HSVtoRGB( PollutedDiffuse );

			// Alpha
			float PollutedAlpha = smoothstep( PollutionTreeAlphaReduce, 1.0f, Diffuse.a );

			// Return
			Diffuse.a = lerp( Diffuse.a, PollutedAlpha, Pollution );
			Diffuse.rgb = lerp( Diffuse.rgb, PollutedDiffuse, Pollution );
		}
		void ApplyDevastationRoads( inout float4 Diffuse, float2 MapCoordinates )
		{
			// Devastation area
			float Devastation = GetDevastation( MapCoordinates ) * 2.0f;
			if( Devastation <= 0.01f ) 
			{
				return;
			}

			// Noise
			float DevastationUVMultiplier = 1800;
			float2 NoiseCoords = MapCoordinates * DevastationUVMultiplier;
			float Noise = PdxTex2D( DevastationPollution, float2( NoiseCoords.x * 2, NoiseCoords.y ) ).a;
			Noise = LevelsScan( Noise, 1.0f - ( Devastation * 0.75f ), 0.1f );

			// Alpha
			Diffuse.a = lerp( Diffuse.a, 0.0f, Noise );
		}

		void ApplyDevastationMaterialVFX( inout float4 Diffuse, float TerrainDetails, float DevastationMask, float2 UV, float2 TerrainBlendFactors )
		{
			// Effect Properties
			float3 BurnColour = float3( 1.0f, 0.3f, 0.0f );

			float InsideEffectStrength = 10.0f;
			float BorderEffectStrength = 5.0f;

			float FireUVDistortionStrength = 0.8f;

			// UV & UV Panning Properties
			float2 UVPan02 = float2( -frac( GlobalTime * 0.005f ), frac( GlobalTime * 0.001f ) );
			float2 UVPan01 = float2( frac( GlobalTime * 0.005f ), frac( GlobalTime * 0.005f ) );

			float2 UV02 = ( UV + 0.5f ) / 5.0f;
			float2 UV01 = UV / 2.0f;

			// Pan and Sample noise for UV distortion
			UV02 += UVPan02;
			float DevastationAlpha02 = PdxTex2D( DevastationPollution, float3( UV02, DevastationTexIndex + DevastationTexIndexOffset ) ).a;

			// Apply the UV Distortion
			UV01 += UVPan01;
			UV01 += DevastationAlpha02 * FireUVDistortionStrength;
			float DevastationAlpha01 = PdxTex2D( DevastationPollution, float3( UV01, DevastationTexIndex + DevastationTexIndexOffset ) ).a;

			// Adjust Mask Value ranges to clamp the effect
			DevastationAlpha01 = smoothstep( 0.2f, 0.5f, DevastationAlpha01 );
			DevastationAlpha02 = smoothstep( 0.5f, 1.0f, DevastationAlpha02 );

			// Calculate the effect masks
			float InsideMask = DevastationAlpha01 * DevastationAlpha02 * DevastationMask * TerrainDetails;
			InsideMask *= InsideEffectStrength;

			float BorderMask = saturate( saturate( TerrainBlendFactors.y - 0.5f ) - saturate( TerrainBlendFactors.y - 0.4f ) );
			BorderMask = saturate( TerrainBlendFactors.x * ( DevastationMask - 0.2f ) ) * DevastationAlpha01;
			BorderMask *= BorderEffectStrength;

			float FinalMask = BorderMask + InsideMask;

			// Return
			float3 Result = lerp( Diffuse.rgb, BurnColour, FinalMask );
			Diffuse.rgb = Result;
		}

		void ApplyDevastationMaterial( inout float4 Diffuse, inout float3 Normal, inout float4 Properties, float2 WorldSpacePosXZ )
		{
			// UVs
			float2 MapCoordinates = WorldSpacePosXZ * WorldSpaceToTerrain0To1;
			float2 DetailUV = CalcDetailUV( WorldSpacePosXZ ) * DevastationTextureTiling;

			// Devastation area
			float Devastation = GetDevastation( MapCoordinates );
			Devastation = clamp( Devastation, 0.0f, DevastationAreaMax );
			if( Devastation <= 0.01f ) 
			{
				return;
			}

			// Diffuse
			float4 DevDiffuse = PdxTex2D( DetailTextures, float3( DetailUV, DevastationTexIndex + DevastationTexIndexOffset ) );
			float3 HSV_ = RGBtoHSV( DevDiffuse.rgb );
			HSV_.x += DevastationHue;			// Hue
			HSV_.y *= DevastationSaturation; 	// Saturation
			HSV_.z *= DevastationValue;			// Value
			DevDiffuse.rgb = HSVtoRGB( HSV_ );

			// Normal
			float4 DevNormalRRxG = PdxTex2D( NormalTextures, float3( DetailUV, DevastationTexIndex + DevastationTexIndexOffset ) );
			float3 DevNormal = UnpackRRxGNormal( DevNormalRRxG ).xyz;

			// Properties
			float4 DevProperties = PdxTex2D( MaterialTextures, float3( DetailUV, DevastationTexIndex + DevastationTexIndexOffset ) );	

			// Exclusion mask
			float DevastationMask = PdxTex2D( DevastationPollution, float2( MapCoordinates.x, MapCoordinates.y ) ).b;
			DevastationMask = smoothstep( DevastationExclusionMaskMin, DevastationExclusionMaskMax, DevastationMask );
			Devastation *= DevastationMask;

			// Terrain material blend
			Diffuse.a = lerp( 0.0f, Diffuse.a, DevastationHeightWeight );				
			DevDiffuse.a = lerp( 1.0f, DevDiffuse.a, 1.0f - DevastationHeightWeight );
			float2 BlendFactors = CalcHeightBlendFactors( float2( Diffuse.a, DevDiffuse.a), float2( 1.0f - Devastation, Devastation ), DetailBlendRange * DevastationHeightContrast );
			
			// Return
			Diffuse = Diffuse * BlendFactors.x + DevDiffuse * BlendFactors.y;

			// Apply VFX on the final Diffuse
			ApplyDevastationMaterialVFX(Diffuse, DevProperties.g, Devastation, DetailUV, BlendFactors);

			Normal = Normal * BlendFactors.x +  DevNormal * BlendFactors.y;
			Properties = Properties * BlendFactors.x + DevProperties * BlendFactors.y;
		}

		void ApplyPollutionMaterial( inout float4 Diffuse, inout float3 Normal, inout float4 Properties, float2 WorldSpacePosXZ, inout float IridescenceMask )
		{
			// UVs
			float2 MapCoordinates = WorldSpacePosXZ * WorldSpaceToTerrain0To1;
			float2 DetailUV = CalcDetailUV( WorldSpacePosXZ ) * PollutionTextureTiling;

			// Pollution area
			float Pollution = GetPollution( MapCoordinates );
			Pollution = Remap( Pollution, 0.0f, 1.0f, 0.0f, PollutionAreaMax );
			if( Pollution <= 0.01f ) 
			{
				return;
			}

			// Diffuse
			float4 PolDiffuse = PdxTex2D( DetailTextures, float3( DetailUV, PollutionTexIndex + PollutionTexIndexOffset ) );

			float3 HSV_ = RGBtoHSV( Diffuse.rgb );
			HSV_.x += PollutionHue;			// Hue
			HSV_.y *= PollutionSaturation; 	// Saturation
			HSV_.z *= PollutionValue;			// Value
			float3 PollutedTerrain = HSVtoRGB( HSV_ );

			float Noise2 = GetPollution( MapCoordinates );
			Diffuse.rgb = lerp( Diffuse.rgb, PollutedTerrain, Noise2 );

			// Normal
			float4 PolNormalRRxG = PdxTex2D( NormalTextures, float3( DetailUV, PollutionTexIndex + PollutionTexIndexOffset ) );
			float3 PolNormal = UnpackRRxGNormal( PolNormalRRxG ).xyz;

			// Properties
			float4 PolProperties = PdxTex2D( MaterialTextures, float3( DetailUV, PollutionTexIndex + PollutionTexIndexOffset ) );	

			// Exclusion mask
			float PollutionMask = PdxTex2D( DevastationPollution, float2( MapCoordinates.x, MapCoordinates.y ) ).b;
			PollutionMask = smoothstep( PollutionExclusionMaskMin, PollutionExclusionMaskMax, PollutionMask );
			Pollution *= PollutionMask;

			// Terrain material blend
			Diffuse.a = lerp( 0.0f, Diffuse.a, PollutionHeightWeight );				
			PolDiffuse.a = lerp( 1.0f, PolDiffuse.a, 1.0f - PollutionHeightWeight );
			float2 BlendFactors = CalcHeightBlendFactors( float2( Diffuse.a, PolDiffuse.a), float2( 1.0f - Pollution, Pollution ), DetailBlendRange * PollutionHeightContrast );

			// Return
			Diffuse = Diffuse * BlendFactors.x + PolDiffuse * BlendFactors.y;
			Normal = Normal * BlendFactors.x + PolNormal * BlendFactors.y;
			Properties = Properties * BlendFactors.x + PolProperties * BlendFactors.y;
			IridescenceMask = BlendFactors.y;
		}

		void GetIridescense( inout SMaterialProperties MaterialProps, float NdotV, PdxTextureSamplerCube EnvironmentMap, float3 WorldSpacePos, inout float IridescenceMask )
		{
			// UVs
			float2 MapCoordinates = WorldSpacePos.xz * WorldSpaceToTerrain0To1;
			float2 DetailUV = CalcDetailUV( WorldSpacePos.xz ) * PollutionTextureTiling;

			// Pollution area
			float Pollution = GetPollution( MapCoordinates );
			Pollution = Remap( Pollution, 0.0f, 1.0f, 0.0f, PollutionAreaMax );
			if( Pollution <= 0.01f ) 
			{
				return;
			}

			// Iridescense noise
			float2 Coords = float2( MapCoordinates.x * 2.0f, MapCoordinates.y ) * IridescenseNoiseTiling;
			float Noise = PdxTex2D( DevastationPollution, Coords ).a;
			Noise = saturate( LevelsScan( Noise, IridescensePosition, IridescenseContrast ) );

			// Weight / Opactity
			IridescenceMask = IridescenceMask * IridescenseOpacity * Noise;

			float3 PolIridescence = MaterialProps._SpecularColor;
			#ifdef HIGH_QUALITY_SHADERS	
				float thickness = abs( IridescenseThicknessMin * ( 1.0 - Noise ) + IridescenseThicknessmax * Noise );
				
				// Specular color
				PolIridescence.r = ThinFilmReflectance( NdotV, IridescenseRed, thickness, IridescenseMediumn, IridescenseFilmn, Iridescenseinternaln ); 		// Red
				PolIridescence.g = ThinFilmReflectance( NdotV, IridescenseGreen, thickness, IridescenseMediumn, IridescenseFilmn, Iridescenseinternaln ); 	// Green
				PolIridescence.b = ThinFilmReflectance( NdotV, IridescenseBlue, thickness, IridescenseMediumn, IridescenseFilmn, Iridescenseinternaln ); 	// Blue

				MaterialProps._SpecularColor = lerp( MaterialProps._SpecularColor, PolIridescence, IridescenceMask );
				MaterialProps._PerceptualRoughness = lerp( MaterialProps._PerceptualRoughness, IridescenseRoughness, IridescenceMask );
				MaterialProps._Roughness = RoughnessFromPerceptualRoughness( MaterialProps._PerceptualRoughness );
			#else
				// Wavelengths sin function
				PolIridescence.r = sin( 2.0f * PI * Noise / ( NdotV * IridescenseRed / 1000.0f ) ) * 0.5 + 0.5;		// Red
				PolIridescence.g = sin( 2.0f * PI * Noise / ( NdotV * IridescenseGreen / 1000.0f ) ) * 0.5 + 0.5;	// Gree
				PolIridescence.b = sin( 2.0f * PI * Noise / ( NdotV * IridescenseBlue / 1000.0f ) ) * 0.5 + 0.5;	// Blue
				PolIridescence *= 0.25f;

				MaterialProps._SpecularColor = lerp( MaterialProps._SpecularColor, PolIridescence, IridescenceMask );
				MaterialProps._PerceptualRoughness = lerp( MaterialProps._PerceptualRoughness, IridescenseRoughness, IridescenceMask );
				MaterialProps._Roughness = RoughnessFromPerceptualRoughness( MaterialProps._PerceptualRoughness );
			#endif
		}

		void CalculateIridescenceRimlight( SMaterialProperties MaterialProps, SLightingProperties LightingProps, inout float3 SpecularLight, float IridescenceMask )
		{
			float3 RimlightVector = normalize( IridescenseRimlightDirection );
			float3 H = normalize( RimlightVector - CameraLookAtDir );
			float NdotL = saturate( dot( MaterialProps._Normal, RimlightVector ) );
			float NdotH = saturate( dot( MaterialProps._Normal, H ) );
			float3 LightIntensity = LightingProps._LightIntensity * NdotL * LightingProps._ShadowTerm;

			// Sun specular light
			float D = D_GGX( NdotH, lerp( 0.03f , 1.0f , MaterialProps._Roughness ) ); 			// Remap to avoid super small and super bright highlights
			float3 SpecularLightRim = D * MaterialProps._SpecularColor * LightIntensity * IridescenseRimlightStrength;

			SpecularLight = SpecularLight + SpecularLightRim;
		}

	]]
}