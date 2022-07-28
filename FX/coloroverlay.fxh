Includes = {
	"cw/pdxterrain.fxh"
	"jomini/jomini_colormap.fxh"
	"jomini/jomini_colormap_constants.fxh"
	"jomini/jomini_province_overlays.fxh"
	"cw/utility.fxh"
	"cw/camera.fxh"
	"sharedconstants.fxh"
}

PixelShader = {

	TextureSampler FlatmapNoiseMap
	{
		Index = 7
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
		File = "gfx/map/textures/flatmap_noise.dds"
		srgb = no
	}

	TextureSampler LandMaskMap
	{
		Index = 9
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
		File = "gfx/map/textures/land_mask.dds"
		srgb = yes
	}

	TextureSampler HighlightGradient
	{
		Ref = HighlightGradient
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}

	TextureSampler ImpassableTerrainTexture
	{
		Ref = ImpassableTerrain
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}

	TextureSampler MapPaintingTextures
	{
		Ref = MapPaintingTexturesRef
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
		type = "2darray"
	}

	TextureSampler CoaAtlas
	{
		Ref = CoaAtlasTexture
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	BufferTexture ProvinceCountryIdBuffer
	{
		Ref = ProvinceCountryId
		type = int
	}
	BufferTexture CountryCoaUvBuffer
	{
		Ref = CountryFlagUvs
		type = float4
	}
	ConstantBuffer( MapCoaConstants0 )
	{
		float MapCoaAngle;
		float MapCoaAspectRatio;
		float MapCoaSize;
		float MapCoaSizeFlatmap;
		float MapCoaBlend;
		float MapCoaBlendFlatmap;
		float MapCoaBlendFadeStart;
		float MapCoaBlendFadeEnd;
		float MapCoaRowOffset;
		float MapCoaRowCount;
		bool  MapCoaEnabled;
	}


	Code
	[[
		#define LAND_COLOR ToLinear( HSVtoRGB( float3( 0.11f, 0.06f, 0.89f ) ) )

		float GameCalculateStripeMask( in float2 UV, float Offset )
		{
			// Diagonal
			float t = 3.14159 / 8.0;
			float w = 8000 - ( 3000 * FlatMapLerp ) - ( 3000 * smoothstep( 2500.0f, 3400.0f, CameraPosition.y ) ); // Simple solution to expand stripes and reduce moiré effect

			float StripeMask = cos( ( UV.x * cos( t ) * w ) + ( UV.y * sin( t ) * w ) + Offset );
			StripeMask = smoothstep( 0.0, 1.0, StripeMask * 2.2f );
			return StripeMask;
		}
		void GameApplyDiagonalStripes( inout float4 BaseColor, float4 StripeColor, float2 WorldSpacePosXZ )
		{
			float Mask = GameCalculateStripeMask( WorldSpacePosXZ, 0.0f );
			Mask *= StripeColor.a;
			BaseColor = lerp( BaseColor, StripeColor, Mask );
		}
		int SampleCountryIndex( float2 MapCoords )
		{
			float2 ColorIndex = PdxTex2D( ProvinceColorIndirectionTexture, MapCoords ).rg;
			int Index = ColorIndex.x * 255.0 + ColorIndex.y * 255.0 * 256.0;
			return PdxReadBuffer( ProvinceCountryIdBuffer, Index ).r;
		}
		void ApplyCoaColorBlend( float2 MapCoords, float2 ParalaxCoord, inout float3 Color, inout float PreLightingBlend, inout float PostLightingBlend )
		{
			//Coat of arms should only be shown in some map modes
			if( !MapCoaEnabled )
			{
				return;
			}

			//Provinces where Controller == Owner will have CountryId -1
			int CountryId = SampleCountryIndex( MapCoords );
			if( CountryId >= 0 )
			{
				float CoaAlpha = 1.0f;
				#ifdef HIGH_QUALITY_SHADERS
					float2 Texel = vec2( 1.0f ) / ProvinceMapSize;
					float2 Pixel = ( MapCoords * ProvinceMapSize + 0.5 );
					float2 FracCoord = frac( Pixel );
					Pixel = floor( Pixel ) / ProvinceMapSize - Texel * 0.5f;
					float C00 = 1.0f - saturate( abs( CountryId - SampleCountryIndex( Pixel ) ) );
					float C10 = 1.0f - saturate( abs( CountryId - SampleCountryIndex( Pixel + float2( Texel.x, 0.0 ) ) ) );
					float C01 = 1.0f - saturate( abs( CountryId - SampleCountryIndex( Pixel + float2( 0.0, Texel.y ) ) ) );
					float C11 = 1.0f - saturate( abs( CountryId - SampleCountryIndex( Pixel + Texel ) ) );
					float x0 = lerp( C00, C10, FracCoord.x );
					float x1 = lerp( C01, C11, FracCoord.x );
					CoaAlpha = RemapClamped( lerp( x0, x1, FracCoord.y ), 0.5f, 0.75f, 0.0f, 1.0f );
				#endif
				float4 FlagUvs = PdxReadBuffer4( CountryCoaUvBuffer, CountryId );
				float2 CoaSize = FlatMapLerp < 0.5f ? float2( MapCoaSize, MapCoaSize / MapCoaAspectRatio ) : float2( MapCoaSizeFlatmap, MapCoaSizeFlatmap / MapCoaAspectRatio );
				float2 CoaUV = ParalaxCoord * ProvinceMapSize / CoaSize;

				//Rotate
				float2 Rotation = float2( cos(MapCoaAngle), sin(MapCoaAngle) );
				CoaUV.x *= MapCoaAspectRatio;
				CoaUV = float2( CoaUV.x * Rotation.x - CoaUV.y * Rotation.y, CoaUV.x * Rotation.y + CoaUV.y * Rotation.x );
				CoaUV.x /= MapCoaAspectRatio;

				float2 CoaDdx = ddx( CoaUV );
				float2 CoaDdy = ddy( CoaUV );

				//Offset rows horizontally
				CoaUV.x += MapCoaRowOffset * int( mod( CoaUV.y, MapCoaRowCount ) );

				//Tile, flip, and scale to match the atlas
				CoaUV = frac( CoaUV );
				CoaUV.y = 1.0f - CoaUV.y;
				CoaUV = FlagUvs.xy + CoaUV * FlagUvs.zw;

				//First blend in gradient border color on top of CoA color
				//Then adjust the border blend value so that CoA is always shown regardless of gradient
				float3 CoaColor = PdxTex2DGrad( CoaAtlas, CoaUV, CoaDdx, CoaDdy ).rgb;
				CoaColor = ToLinear( CoaColor );

				float Opacity = CoaAlpha * ( MapCoaBlend * ( 1.0f - FlatMapLerp ) ) + ( MapCoaBlendFlatmap * FlatMapLerp );

				float FadeStart = ( MapCoaBlendFadeStart - MapCoaBlendFadeEnd );
				float CloseZoomBlend = FadeStart - CameraPosition.y + ( MapCoaBlendFadeEnd );
				CloseZoomBlend = smoothstep( FadeStart, 0.0f, CloseZoomBlend );
				Opacity *= CloseZoomBlend;

				PreLightingBlend = max( Opacity, PreLightingBlend );


				Color = lerp( Color, CoaColor, Opacity );
			}
 		}

		void ApplyLensTextureAndAlpha( inout float3 Color, inout float alpha, float Mask, float2 UV, int index )
		{
			float4 LensModeTexure = PdxTex2D( MapPaintingTextures, float3( UV, index ) );
			Color = lerp( Color, LensModeTexure.rgb, Mask * LensModeTexure.a );
			alpha = lerp( alpha, alpha * LensModeTexure.a, Mask );
		}

		void OverlayLensTexture( inout float3 Color, float Mask, float2 UV, int index )
		{
			float4 LensModeTexure = PdxTex2D( MapPaintingTextures, float3( UV, index ) );
			Color = Overlay( Color, LensModeTexure.rgb, Mask * LensModeTexure.a );
		}

		void GameProvinceOverlayAndBlend( float2 ColorMapCoords, float3 WorldSpacePos, out float3 ColorOverlay, out float PreLightingBlend, out float PostLightingBlend )
		{
			// Paralx Coord
			float3 ToCam = normalize( CameraPosition - WorldSpacePos );
			float ParalaxDist = ( ImpassableTerrainHeight - WorldSpacePos.y ) / ToCam.y;
			float3 ParalaxCoord = WorldSpacePos + ToCam * ParalaxDist;
			ParalaxCoord.xz = ParalaxCoord.xz * WorldSpaceToTerrain0To1;

			float DistanceFieldValue = CalcDistanceFieldValue( ColorMapCoords );
			float Edge = smoothstep( GB_EdgeWidth + max( 0.001f, GB_EdgeSmoothness ), GB_EdgeWidth, DistanceFieldValue );

			// Default color
			ColorOverlay = LAND_COLOR;

			// Standard color
			float4 ProvinceOverlayColorWithAlpha = vec4( 0.0f );

			// Mask for texture usage
			float4 MainColorMask = BilinearColorSample( ColorMapCoords, IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture );
			float4 SecondaryColorMask = BilinearColorSampleAtOffset( ColorMapCoords, IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, SecondaryProvinceColorsOffset );
			float4 AlternateColorMask = BilinearColorSampleAtOffset( ColorMapCoords, IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, AlternateProvinceColorsOffset );
			float4 HighlightColor = BilinearColorSampleAtOffset( ColorMapCoords, IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, HighlightProvinceColorsOffset );

			// Land/Ocean/Lake masks
			float LandMask = PdxTex2DLod0( LandMaskMap, float2( ColorMapCoords.x, 1.0f - ColorMapCoords.y ) ).r;
			float EndLandMask = 0.0f;
			float ShoreLinesStripes = 0.0f;

			float4 LakeColor = float4( 0.0f, 0.0f, 0.0f, 1.0f );	// Needs to match color in mappaintingmanager.cpp
			float4 AlternateColor = BilinearColorSampleAtOffset( ColorMapCoords, IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, AlternateProvinceColorsOffset );
			float4 LakeDiff = LakeColor - AlternateColor;

			// Not a lake and doesn't have water mass
			if( LandMask <= 0.0f || dot( LakeDiff, LakeDiff ) > 0.1f )
			{
				float4 SeaColor = float4( 0.0f, 0.0f, 1.0f, 0.0f );	// Needs to match color in mappaintingmanager.cpp
				float4 SeaDiff = SeaColor - AlternateColor;

				// Not a sea, so we can use regular landmask
				if( dot( SeaDiff, SeaDiff ) > 0.1f )
				{
					EndLandMask = LandMask;
				}
			}

			// Primary as texture or color
			if ( !_UseMapmodeTextures )
			{
				// Get color
				ProvinceOverlayColorWithAlpha = CalcPrimaryProvinceOverlay( ColorMapCoords, DistanceFieldValue );

				// Apply decentralized country color
				float4 DecentralizedColor = DecentralizedCountryColor;
				float DecentralizedMask = saturate( 1.0f - Edge );

				DecentralizedColor.rgb = DecentralizedCountryColor.rgb;
				DecentralizedColor.a *= AlternateColorMask.g;
				DecentralizedMask = DecentralizedMask * DecentralizedColor.a * FlatMapLerp;
				ProvinceOverlayColorWithAlpha = lerp( ProvinceOverlayColorWithAlpha, DecentralizedColor, DecentralizedMask );

				// Apply impassable terrain color
				float4 ImpassableDiffuse = float4( PdxTex2D( ImpassableTerrainTexture, float2( ParalaxCoord.x * 2.0f, 1.0f - ParalaxCoord.z ) * ImpassableTerrainTiling ).rgb,  AlternateColorMask.r );
				ImpassableDiffuse.rgb = Lighten( ImpassableDiffuse.rgb, ImpassableTerrainColor.rgb );
				float ImpassableMask = ImpassableDiffuse.a * ImpassableTerrainColor.a * ( 1.0f - FlatMapLerp );

				// Fade impassable close
				float FadeStart = ( ImpassableTerrainFadeStart - ImpassableTerrainFadeEnd );
				float CloseZoomBlend = FadeStart - CameraPosition.y + ImpassableTerrainFadeEnd;
				CloseZoomBlend = smoothstep( FadeStart, 0.0f, CloseZoomBlend );
				ImpassableMask *= CloseZoomBlend;
				ProvinceOverlayColorWithAlpha = lerp( ProvinceOverlayColorWithAlpha, ImpassableDiffuse, ImpassableMask );


				// Apply stripes
				float4 SecondaryColor = BilinearColorSampleAtOffset( ColorMapCoords, IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, SecondaryProvinceColorsOffset );
				SecondaryColor.a *= smoothstep( GB_EdgeWidth, GB_EdgeWidth + 0.01f, DistanceFieldValue );
				ProvinceOverlayColorWithAlpha = lerp( ProvinceOverlayColorWithAlpha, SecondaryColor, SecondaryColor.a );

				// Get blendmode
				GetGradiantBorderBlendValues( ProvinceOverlayColorWithAlpha, PreLightingBlend, PostLightingBlend );

				// Apply impassable terrain blendmode
				PreLightingBlend = lerp( PreLightingBlend, 0.0f, ImpassableMask );
				PostLightingBlend = lerp( PostLightingBlend, 1.0f, ImpassableMask );


				// Apply output
				ColorOverlay = ProvinceOverlayColorWithAlpha.rgb;
			}
			else
			{
				float2 LensUVs = float2( ParalaxCoord.x * 2.0f, 1.0f - ParalaxCoord.z ) * _MapPaintingTextureTiling;

				float LensTextureAlpha = 1.0f;
				ApplyLensTextureAndAlpha( ColorOverlay, LensTextureAlpha, MainColorMask.r, LensUVs, 0 );
				ApplyLensTextureAndAlpha( ColorOverlay, LensTextureAlpha, MainColorMask.g, LensUVs, 1 );
				ApplyLensTextureAndAlpha( ColorOverlay, LensTextureAlpha, MainColorMask.b, LensUVs, 2 );
				ApplyLensTextureAndAlpha( ColorOverlay, LensTextureAlpha, MainColorMask.a, LensUVs, 3 );

				ApplyLensTextureAndAlpha( ColorOverlay, LensTextureAlpha, SecondaryColorMask.r, LensUVs, 4 );
				ApplyLensTextureAndAlpha( ColorOverlay, LensTextureAlpha, SecondaryColorMask.g, LensUVs, 5 );
				ApplyLensTextureAndAlpha( ColorOverlay, LensTextureAlpha, SecondaryColorMask.b, LensUVs, 6 );
				ApplyLensTextureAndAlpha( ColorOverlay, LensTextureAlpha, SecondaryColorMask.a, LensUVs, 7 );

				ApplyLensTextureAndAlpha( ColorOverlay, LensTextureAlpha, AlternateColorMask.r, LensUVs, 8 );
				ApplyLensTextureAndAlpha( ColorOverlay, LensTextureAlpha, AlternateColorMask.g, LensUVs, 9 );

				float AlphaMask = MainColorMask.r + MainColorMask.g + MainColorMask.b + MainColorMask.a;
				AlphaMask += SecondaryColorMask.r + SecondaryColorMask.g + SecondaryColorMask.b + SecondaryColorMask.a;
				AlphaMask += AlternateColorMask.r + AlternateColorMask.g;
				AlphaMask = saturate( AlphaMask * EndLandMask * LensTextureAlpha );

				ProvinceOverlayColorWithAlpha.a = lerp( ProvinceOverlayColorWithAlpha.a, 1.0f, AlphaMask );

				// Get blendmode
				GetGradiantBorderBlendValues( ProvinceOverlayColorWithAlpha, PreLightingBlend, PostLightingBlend );
			}

			// Apply stylised noise
			#ifndef LOW_QUALITY_SHADERS
				#if defined( TERRAIN_FLAT_MAP ) || defined( TERRAIN_FLAT_MAP_LERP )
					float DetailScale1 = 10.0f;
					float DetailScale2 = 3.0f;
					float DetailTexture1 = PdxTex2D( FlatmapNoiseMap, float2( ( ColorMapCoords.x * DetailScale1 * 2.0f ), 1.0f - ( ColorMapCoords.y * DetailScale1 ) ) ).g;
					float DetailTexture2 = PdxTex2D( FlatmapNoiseMap, float2( ( ColorMapCoords.x * DetailScale2 * 2.0f ), 1.0f - ( ColorMapCoords.y * DetailScale2 ) ) ).g;
					float DetailTexture3 = GetOverlay( DetailTexture1,  DetailTexture2, 1.0f );

					// Don't blend in mapmodes
					if ( !_UseMapmodeTextures )
					{
						ColorOverlay = saturate( GetOverlay( ColorOverlay, vec3( 1.0f - DetailTexture3 ), FlatMapLerp ) );
					}

				#endif
			#endif

			ApplyCoaColorBlend( ColorMapCoords, ParalaxCoord.xz, ColorOverlay, PreLightingBlend, PostLightingBlend );
		}

		float3 ApplyDynamicFlatmap( float3 FlatMapDiffuse, float2 ColorMapCoords, float2 WorldSpacePosXZ )
		{
			float ExtentStr = ShorelineExtentStr;
			float Alpha = ShorelineAlpha;
			float UVScale = ShoreLinesUVScale;

			#ifndef LOW_QUALITY_SHADERS
				float MaskBlur = ShorelineMaskBlur;
				float LandMaskBlur = PdxTex2DLod( LandMaskMap, float2( ColorMapCoords.x, 1.0f - ColorMapCoords.y ), MaskBlur ).r;
				float ShoreLines = PdxTex2D( FlatmapNoiseMap, ColorMapCoords * UVScale ).r;
				ShoreLines *= saturate( Alpha );
			#endif

			// Land color
			float3 Land = LAND_COLOR;

			float LandMask = PdxTex2DLod0( LandMaskMap, float2( ColorMapCoords.x, 1.0f - ColorMapCoords.y ) ).r;
			float EndLandMask = 0.0f;
			float ShoreLinesStripes = 0.0f;

			float4 LakeColor = float4( 0.0f, 0.0f, 0.0f, 1.0f ); // Needs to match color in mappaintingmanager.cpp
			float4 AlternateColor = BilinearColorSampleAtOffset( ColorMapCoords, IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, AlternateProvinceColorsOffset );
			float4 LakeDiff = LakeColor - AlternateColor;
			// Not a lake and doesn't have water mass
			if( LandMask <= 0.0f || dot( LakeDiff, LakeDiff ) > 0.1f )
			{
				#ifndef LOW_QUALITY_SHADERS
					ShoreLinesStripes = saturate( LandMaskBlur * ShoreLines * ShorelineExtentStr );
				#endif
				ShoreLinesStripes = saturate( ShoreLinesStripes * ShorelineAlpha );
				ShoreLinesStripes = clamp( ShoreLinesStripes, 0.0, 0.5f );
				FlatMapDiffuse = lerp( FlatMapDiffuse, vec3( 0.0f ), ShoreLinesStripes );

				float4 SeaColor = float4( 0.0f, 0.0f, 1.0f, 0.0f );	// Needs to match color in mappaintingmanager.cpp
				float4 SeaDiff = SeaColor - AlternateColor;

				// Not a sea, so we can use regular landmask
				if( dot( SeaDiff, SeaDiff ) > 0.1f )
				{
					EndLandMask = LandMask;
				}
			}

			// Blends in shorelines/flatmap color adjustments
			FlatMapDiffuse = lerp( FlatMapDiffuse, Land, EndLandMask );

			return FlatMapDiffuse;
		}

		// Convenicence function for changing blend modes in all shaders
		float3 ApplyColorOverlay( float3 Color, float3 ColorOverlay, float Blend )
		{
			float3 HSV_ = RGBtoHSV( ColorOverlay.rgb );
			HSV_.x += 0.0f;		// Hue
			HSV_.y *= 0.95f; 	// Saturation
			HSV_.z *= 0.35f;	// Value
			ColorOverlay.rgb = lerp( ColorOverlay.rgb, HSVtoRGB( HSV_ ), 1.0f - FlatMapLerp );

			Color = lerp( Color, ColorOverlay, Blend );
			return Color;
		}

		float3 ApplyHighlight( float3 Color, float2 Coordinate )
		{
			float Gradient = PdxTex2D( HighlightGradient, Coordinate ).r;

			float SignleSamplingSafeDistance = 0.49f;
			float4 HighlightColor = vec4( 0 );
			if( abs( 0.5f - PdxTex2D( HighlightGradient, Coordinate ).r ) > SignleSamplingSafeDistance )
			{
				// Optimisation - We can use the gradient to quickly gauge where it's safe to use a single sample
				// If the gradient is close to 0.5 then there is a color change somewhere nearby, and multi sampling is needed.
				// Otherwise a single sample will do
				HighlightColor = ColorSampleAtOffset( Coordinate, ProvinceColorIndirectionTexture, ProvinceColorTexture, HighlightProvinceColorsOffset );
			}
			else
			{
			#ifdef HIGH_QUALITY_SHADERS
				// Lots of double samples here
				// There's no meassurable difference between this naive implementation and a bespoke
				// implementation for reducing the number of samples (on GTX 1080Ti) so assuming the
				// the texture cache is able to handle this just fine.
				// Naive implementation reduces code duplication and makes code simpler
				float2 Offset = InvIndirectionMapSize;
				HighlightColor += BilinearColorSampleAtOffset( Coordinate + Offset * float2( -1, -1 ), IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, HighlightProvinceColorsOffset );
				HighlightColor += BilinearColorSampleAtOffset( Coordinate + Offset * float2(  0, -1 ), IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, HighlightProvinceColorsOffset );
				HighlightColor += BilinearColorSampleAtOffset( Coordinate + Offset * float2(  1, -1 ), IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, HighlightProvinceColorsOffset );

				HighlightColor += BilinearColorSampleAtOffset( Coordinate + Offset * float2( -1,  0 ), IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, HighlightProvinceColorsOffset );
				HighlightColor += BilinearColorSampleAtOffset( Coordinate + Offset * float2(  0,  0 ), IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, HighlightProvinceColorsOffset );
				HighlightColor += BilinearColorSampleAtOffset( Coordinate + Offset * float2(  1,  0 ), IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, HighlightProvinceColorsOffset );

				HighlightColor += BilinearColorSampleAtOffset( Coordinate + Offset * float2( -1,  1 ), IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, HighlightProvinceColorsOffset );
				HighlightColor += BilinearColorSampleAtOffset( Coordinate + Offset * float2(  0,  1 ), IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, HighlightProvinceColorsOffset );
				HighlightColor += BilinearColorSampleAtOffset( Coordinate + Offset * float2(  1,  1 ), IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, HighlightProvinceColorsOffset );
				HighlightColor /= 9.0f;
			#else
				HighlightColor = BilinearColorSampleAtOffset( Coordinate, IndirectionMapSize, InvIndirectionMapSize, ProvinceColorIndirectionTexture, ProvinceColorTexture, HighlightProvinceColorsOffset );
			#endif
			}

			HighlightColor.a *= 1.0f - Gradient;
			Color = lerp( Color, HighlightColor.rgb, HighlightColor.a );
			return Color;
		}
	]]
}
