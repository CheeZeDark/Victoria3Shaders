Includes = {
	"cw/pdxmesh.fxh"
	"cw/pdxterrain.fxh"
	"cw/utility.fxh"
	"cw/curve.fxh"
	"cw/shadow.fxh"
	"cw/camera.fxh"
	"cw/heightmap.fxh"
	"cw/alpha_to_coverage.fxh"
	"jomini/jomini_lighting.fxh"
	"jomini/jomini_water.fxh"
	"jomini/jomini_mapobject.fxh"
	"jomini/jomini_province_overlays.fxh"
	"pdxmesh_functions.fxh"
	"constants.fxh"
	"sharedconstants.fxh"
	"fog_of_war.fxh"
	"distance_fog.fxh"
	"coloroverlay.fxh"
	"ssao_struct.fxh"
}

PixelShader =
{
	TextureSampler DiffuseMap
	{
		Ref = PdxTexture0
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler PropertiesMap
	{
		Ref = PdxTexture1
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
	}
	TextureSampler NormalMap
	{
		Ref = PdxTexture2
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
	TextureSampler UniqueMap
    {
        Index = 5
        MagFilter = "Linear"
        MinFilter = "Linear"
        MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
    }
	TextureSampler ShadowMap
	{
		Ref = PdxShadowmap
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
		CompareFunction = less_equal
		SamplerType = "Compare"
	}
	TextureSampler FlagMap
	{
		Ref = PdxMeshCustomTexture0
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Wrap"
		
		file = "gfx/models/buildings/generic/flag/flag.dds"
		srgb = yes
	}
}

VertexStruct VS_OUTPUT
{
    float4 Position			: PDX_POSITION;
	float3 Normal			: TEXCOORD0;
	float3 Tangent			: TEXCOORD1;
	float3 Bitangent		: TEXCOORD2;
	float2 UV0				: TEXCOORD3;
	float2 UV1				: TEXCOORD4;
	float3 WorldSpacePos	: TEXCOORD5;
	uint InstanceIndex 	: TEXCOORD6;
};

VertexShader =
{
	Code
	[[
		VS_OUTPUT ConvertOutput( VS_OUTPUT_PDXMESH In )
		{
			VS_OUTPUT Out;
			
			Out.Position = In.Position;
			Out.Normal = In.Normal;
			Out.Tangent = In.Tangent;
			Out.Bitangent = In.Bitangent;
			Out.UV0 = In.UV0;
			Out.UV1 = In.UV1;
			Out.WorldSpacePos = In.WorldSpacePos;
			return Out;
		}
	]]
	
	MainCode VS_standard
	{
		Input = "VS_INPUT_PDXMESHSTANDARD"
		Output = "VS_OUTPUT"
		Code
		[[
			PDX_MAIN
			{
				#ifdef WINDTRANSFORM
					float4x4 WorldMatrix = PdxMeshGetWorldMatrix( Input.InstanceIndices.y );
					Input.Position = WindTransform( Input.Position, WorldMatrix );
				#endif

				VS_OUTPUT Out = ConvertOutput( PdxMeshVertexShaderStandard( Input ) );
				Out.InstanceIndex = Input.InstanceIndices.y;
				return Out;
			}
		]]
	}
	MainCode VS_mapobject
	{
		Input = "VS_INPUT_PDXMESH_MAPOBJECT"
		Output = "VS_OUTPUT"
		Code
		[[
			PDX_MAIN
			{
				#ifdef WINDTRANSFORM
					float4x4 WorldMatrix = UnpackAndGetMapObjectWorldMatrix( Input.InstanceIndex24_Opacity8 );
					Input.Position = WindTransform( Input.Position, WorldMatrix );
				#endif
				
				VS_OUTPUT Out = ConvertOutput( PdxMeshVertexShader( PdxMeshConvertInput( Input ), Input.InstanceIndex24_Opacity8, UnpackAndGetMapObjectWorldMatrix( Input.InstanceIndex24_Opacity8 ) ) );
				Out.InstanceIndex = Input.InstanceIndex24_Opacity8;
				return Out;
			}
		]]
	}
	MainCode VS_sine_animation
	{
		Input = "VS_INPUT_PDXMESHSTANDARD"
		Output = "VS_OUTPUT"
		Code
		[[
			PDX_MAIN
			{
				CalculateSineAnimation( Input.UV0, Input.Position, Input.Normal, Input.Tangent );
				VS_OUTPUT Out = ConvertOutput( PdxMeshVertexShaderStandard( Input ) );
				Out.InstanceIndex = Input.InstanceIndices.y;
				return Out;
			}
		]]
	}
	
	MainCode VS_sine_animation_uv_1
	{
		Input = "VS_INPUT_PDXMESHSTANDARD"
		Output = "VS_OUTPUT"
		Code
		[[
			PDX_MAIN
			{
				#ifdef PDX_MESH_UV1
				CalculateSineAnimation( Input.UV1, Input.Position, Input.Normal, Input.Tangent );
				#endif
				VS_OUTPUT Out = ConvertOutput( PdxMeshVertexShaderStandard( Input ) );
				Out.InstanceIndex = Input.InstanceIndices.y;
				return Out;
			}
		]]
	}
	MainCode VS_sine_animation_shadow
	{
		Input = "VS_INPUT_PDXMESHSTANDARD"
		Output = "VS_OUTPUT_PDXMESHSHADOWSTANDARD"
		Code
		[[
			PDX_MAIN
			{
				CalculateSineAnimation( Input.UV0, Input.Position, Input.Normal, Input.Tangent );
				return PdxMeshVertexShaderShadowStandard( Input );
			}
		]]
	}
}


PixelShader =
{
	Code
	[[
		float ApplyOpacity( float BaseAlpha, float2 NoiseCoordinate, in uint InstanceIndex )
		{
		#ifdef JOMINI_MAP_OBJECT
			float Opacity = UnpackAndGetMapObjectOpacity( InstanceIndex );
		#else
			float Opacity = PdxMeshGetOpacity( InstanceIndex );
		#endif
			return PdxMeshApplyOpacity( BaseAlpha, NoiseCoordinate, Opacity );
		}
	]]
	MainCode PS_standard
	{
		Input = "VS_OUTPUT"
		Output = "PS_COLOR_SSAO"
		Code
		[[			
			#if defined( ATLAS )
				#ifndef DIFFUSE_UV_SET
					#define DIFFUSE_UV_SET Input.UV1
				#endif
				
				#ifndef NORMAL_UV_SET
					#define NORMAL_UV_SET Input.UV1
				#endif
				
				#ifndef PROPERTIES_UV_SET
					#define PROPERTIES_UV_SET Input.UV1
				#endif
				
				#ifndef UNIQUE_UV_SET
					#define UNIQUE_UV_SET Input.UV0
				#endif
			#else
				#ifndef DIFFUSE_UV_SET
					#define DIFFUSE_UV_SET Input.UV0
				#endif
				
				#ifndef NORMAL_UV_SET
					#define NORMAL_UV_SET Input.UV0
				#endif
				
				#ifndef PROPERTIES_UV_SET
					#define PROPERTIES_UV_SET Input.UV0
				#endif
			#endif
			PDX_MAIN
			{
				PS_COLOR_SSAO Out;

				float4 Diffuse = PdxTex2D( DiffuseMap, DIFFUSE_UV_SET );
				float4 Properties = PdxTex2D( PropertiesMap, PROPERTIES_UV_SET );
				float2 MapCoords = Input.WorldSpacePos.xz * WorldSpaceToTerrain0To1;
				float2 ProvinceCoords = Input.WorldSpacePos.xz / ProvinceMapSize;

				// Alpha
				Diffuse.a = ApplyOpacity( Diffuse.a, Input.Position.xy, Input.InstanceIndex );
				#ifdef ALPHA_TO_COVERAGE
					Diffuse.a = RescaleAlphaByMipLevel( Diffuse.a, Input.UV0, DiffuseMap ) ;
					Diffuse.a = SharpenAlpha( Diffuse.a, 0.5f ) ;
					clip( Diffuse.a - 0.001f );
				#endif
				clip( Diffuse.a - 0.001f );
				
				// Normal calculation
				float3 NormalSample = UnpackRRxGNormal( PdxTex2D( NormalMap, NORMAL_UV_SET ) );
				float3 InNormal = normalize( Input.Normal );
				float3x3 TBN = Create3x3( normalize( Input.Tangent ), normalize( Input.Bitangent ), InNormal );
				float3 Normal = normalize( mul( NormalSample, TBN ) );

				#if defined( ATLAS )
					float4 Unique = PdxTex2D( UniqueMap, UNIQUE_UV_SET );
					
					// Blend normals
					float3 UniqueNormalSample = UnpackRRxGNormal( Unique );
					NormalSample = ReorientNormal( UniqueNormalSample, NormalSample );

					// Multiply AO
					Diffuse.rgb *= Unique.bbb;
				#endif

				// Bottom tint effetc
				float TintAngleModifier = saturate( 1.0f - dot( InNormal, float3( 0.0f, 1.0f, 0.0f ) ) );	// Removes tint from angles facing upwards
				float LocalHeight = Input.WorldSpacePos.y - GetHeight( Input.WorldSpacePos.xz );
				float TintBlend = ( 1.0f - smoothstep( MeshTintHeightMin, MeshTintHeightMax, LocalHeight ) ) * MeshTintColor.a * TintAngleModifier;
				Diffuse.rgb = lerp(  Diffuse.rgb, Overlay(Diffuse.rgb, MeshTintColor.rgb), TintBlend );

				// Colormap blend, pre light
				#if defined( COLORMAP )
					float3 ColorMap = PdxTex2D( ColorTexture, float2( MapCoords.x, 1.0 - MapCoords.y ) ).rgb;
					Diffuse.rgb = SoftLight( Diffuse.rgb, ColorMap, ( 1 - Properties.r ) * COLORMAP_OVERLAY_STRENGTH );
				#endif	

				// Color overlay, pre light
				#ifndef NO_BORDERS
					float3 ColorOverlay;
					float PreLightingBlend;
					float PostLightingBlend;
					GameProvinceOverlayAndBlend( ProvinceCoords, Input.WorldSpacePos, ColorOverlay, PreLightingBlend, PostLightingBlend );
					Diffuse.rgb = ApplyColorOverlay( Diffuse.rgb, ColorOverlay, PreLightingBlend );
				#endif
				
				// Usercolor, ?
				float3 UserColor = float3( 1.0f, 1.0f, 1.0f );
				#if defined( USER_COLOR )
					//float3 UserColor1 = GetUserData( Input.InstanceIndex, USER_DATA_PRIMARY_COLOR ).rgb;
					//float3 UserColor2 = GetUserData( Input.InstanceIndex, USER_DATA_SECONDARY_COLOR ).rgb;
					float3 UserColor1 = float3( 199.0/255.0, 16.0/255.0, 46.0/255.0 ); // red
					float3 UserColor2 = float3( 1.0/255.0, 32.0/255.0, 105.0/255.0 ); // blue
					
					UserColor = lerp( UserColor, UserColor1, Properties.r );
					UserColor = lerp( UserColor, UserColor2, PdxTex2D( NormalMap, NORMAL_UV_SET ).b );
				#endif
				#if defined( COA )
					//float4 CoAAtlasSlot = GetUserData( Input.InstanceIndex, USER_DATA_ATLAS_SLOT );
					//float2 FlagCoords = CoAAtlasSlot.xy + ( MirrorOutsideUV( Input.UV1 ) * CoAAtlasSlot.zw );
					float2 FlagCoords = Input.UV0;
					UserColor = lerp( UserColor, PdxTex2D( FlagMap, FlagCoords ).rgb, 1 );
				#endif
				Diffuse.rgb *= UserColor;

				// Light and shadow
				float3 Color = Diffuse.rgb;
				SMaterialProperties MaterialProps = GetMaterialProperties( Diffuse.rgb, Normal, Properties.a, Properties.g, Properties.b );
				SLightingProperties LightingProps = GetSunLightingProperties( Input.WorldSpacePos, ShadowMap );
				#ifndef LOW_QUALITY_SHADERS
					Color = CalculateSunLighting( MaterialProps, LightingProps, EnvironmentMap );
				#endif
				
				// Effects, post light
				#ifndef UNDERWATER
					#ifndef NO_BORDERS
						Color = ApplyColorOverlay( Color, ColorOverlay, PostLightingBlend );
					#endif
					#ifndef NO_FOG
						if( FlatMapLerp < 1.0f ) 
						{
							float3 Unfogged = Color;
							Color = ApplyFogOfWar( Color, Input.WorldSpacePos, FogOfWarAlpha );
							Color = GameApplyDistanceFog( Color, Input.WorldSpacePos );
							Color = lerp( Color, Unfogged, FlatMapLerp );
						}
					#endif
				#endif
				
				//
				#ifdef UNDERWATER
					clip( _WaterHeight - Input.WorldSpacePos.y + 0.1 ); // +0.1 to avoid gap between water and mesh				
					Diffuse.a = CompressWorldSpace( Input.WorldSpacePos );
				#endif
				
				// Province Highlight
				Color = ApplyHighlight( Color, ProvinceCoords );
						
				//
				#ifdef FLATMAP
					float OpacityOnLand = 0.25;
				 	float LandMask = PdxTex2DLod0( LandMaskMap, float2( MapCoords.x, 1.0 - MapCoords.y ) ).r;
					Diffuse.a *= ( 1 - ( LandMask * ( 1 - OpacityOnLand ) ) );
				#endif

				// Debug
				DebugReturn( Color, MaterialProps, LightingProps, EnvironmentMap );

				// Output
				Out.Color = float4( Color, Diffuse.a );
				float3 SSAOColor_ = SSAOColorMesh.rgb + GameCalculateDistanceFogFactor( Input.WorldSpacePos );
				#ifndef NO_BORDERS
					SSAOColor_ = SSAOColor_ + PostLightingBlend;
				#endif
				Out.SSAOColor = float4( saturate ( SSAOColor_ ), Diffuse.a);

				return Out;
			}
		]]
	}
}


BlendState BlendState
{
	BlendEnable = no
}
BlendState alpha_blend
{
	BlendEnable = yes
	SourceBlend = "SRC_ALPHA"
	DestBlend = "INV_SRC_ALPHA"
}
BlendState alpha_to_coverage
{
	BlendEnable = no
	SourceBlend = "SRC_ALPHA"
	DestBlend = "INV_SRC_ALPHA"
	AlphaToCoverage = yes
}

DepthStencilState depth_test_no_write
{
	DepthEnable = yes
	DepthWriteEnable = no
}

RasterizerState RasterizerState
{
	DepthBias = 0
	SlopeScaleDepthBias = 0
}
RasterizerState ShadowRasterizerState
{
	DepthBias = 0
	SlopeScaleDepthBias = 2
}
RasterizerState FlatmapRasterizerState
{
	DepthBias = -500
	SlopeScaleDepthBias = -7
}


Effect standard
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
}
Effect standardShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"	
	RasterizerState = ShadowRasterizerState
}
Effect standard_atlas
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	Defines = { "ATLAS" }
}
Effect standard_atlasShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"		
	RasterizerState = ShadowRasterizerState
}

Effect standard_alpha_blend
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	BlendState = "alpha_blend"
	DepthStencilState = "depth_test_no_write"
}
Effect standard_alpha_blendShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshAlphaBlendShadow"
	RasterizerState = ShadowRasterizerState
}
Effect standard_alpha_to_coverage
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	BlendState = "alpha_to_coverage"
	Defines = { "ALPHA_TO_COVERAGE" }
}
Effect standard_alpha_to_coverageShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshAlphaBlendShadow"
	RasterizerState = ShadowRasterizerState
	Defines = { "ALPHA_TO_COVERAGE" }
}
Effect standard_colormap
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	Defines = { "COLORMAP" }
}
Effect standard_colormapShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"	
	RasterizerState = ShadowRasterizerState
}
Effect standard_atlas_colormap
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	Defines = { "ATLAS" "COLORMAP" }
}
Effect standard_atlas_colormapShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"	
	RasterizerState = ShadowRasterizerState
}
Effect standard_flag
{
	VertexShader = "VS_sine_animation"
	PixelShader = "PS_standard"
	Defines = { "COA" }
}
Effect standard_flag_usercolor
{
	VertexShader = "VS_sine_animation_uv_1"
	PixelShader = "PS_standard"
}
Effect standard_flagShadow
{
	VertexShader = "VS_sine_animation_shadow"
	PixelShader = "PixelPdxMeshStandardShadow"
	RasterizerState = ShadowRasterizerState
}
Effect standard_usercolor
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	Defines = { "USER_COLOR" }
}
Effect standard_usercolorShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"		
	RasterizerState = ShadowRasterizerState
}
Effect standard_usercolor_coa
{
	VertexShader = "VS_sine_animation"
	PixelShader = "PS_standard"
	Defines = { "USER_COLOR" "COA"  }
}
Effect standard_usercolor_coaShadow
{
	VertexShader = "VS_sine_animation_shadow"
	PixelShader = "PixelPdxMeshStandardShadow"		
	RasterizerState = ShadowRasterizerState
}
Effect standard_no_borders
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	Defines = { "NO_BORDERS"  }
}
Effect standard_no_bordersShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"	
	RasterizerState = ShadowRasterizerState
}
Effect standard_alpha_blend_no_borders
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	BlendState = "alpha_blend"
	DepthStencilState = "depth_test_no_write"
	Defines = { "NO_BORDERS"  }
}
Effect standard_alpha_blend_no_bordersShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshAlphaBlendShadow"	
	RasterizerState = ShadowRasterizerState
}
Effect standard_treetrunk
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"	
	Defines = { "WINDTRANSFORM" }
}



Effect flatmap_alpha_blend
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	BlendState = "alpha_blend"
	DepthStencilState = "depth_test_no_write"
	RasterizerState = FlatmapRasterizerState
	Defines = { "NO_FOG" }	
}
Effect flatmap_alpha_blendShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshAlphaBlendShadow"
	Defines = { "NO_FOG" }	
}
Effect flatmap_alpha_blend_no_borders
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	BlendState = "alpha_blend"
	DepthStencilState = "depth_test_no_write"
	RasterizerState = FlatmapRasterizerState
	Defines = { "NO_BORDERS" "NO_FOG"  }
}
Effect flatmap_alpha_blend_no_bordersShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshAlphaBlendShadow"
	Defines = { "NO_FOG" }		
	RasterizerState = ShadowRasterizerState
}



Effect snap_to_terrain
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN" }
}
Effect snap_to_terrainShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshStandardShadow"	
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN" }
	RasterizerState = ShadowRasterizerState
}
Effect snap_to_terrain_alpha_to_coverage
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	BlendState = "alpha_to_coverage"
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN" "ALPHA_TO_COVERAGE" }
}
Effect snap_to_terrain_alpha_to_coverageShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshAlphaBlendShadow"
	RasterizerState = ShadowRasterizerState
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN" "ALPHA_TO_COVERAGE" }
}
Effect snap_to_terrain_alpha_to_coverage_colormap
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	BlendState = "alpha_to_coverage"
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN" "COLORMAP" "ALPHA_TO_COVERAGE" }
}
Effect snap_to_terrain_alpha_to_coverage_colormapShadow
{
	VertexShader = "VertexPdxMeshStandardShadow"
	PixelShader = "PixelPdxMeshAlphaBlendShadow"
	RasterizerState = ShadowRasterizerState
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN" "ALPHA_TO_COVERAGE" }
}
Effect snap_to_terrain_treetrunk
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN" "WINDTRANSFORM" }
}



Effect material_test
{
	VertexShader = "VS_standard"
	PixelShader = "PS_standard"
	Defines = { "NORMAL_UV_SET Input.UV1" "DIFFUSE_UV_SET Input.UV1" }
}



#Map object shaders
Effect standard_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
}
Effect standardShadow_mapobject
{
	VertexShader = "VS_jomini_mapobject_shadow"
	PixelShader = "PS_jomini_mapobject_shadow"
	RasterizerState = ShadowRasterizerState
}

Effect standard_atlas_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
	Defines = { "ATLAS" }
}
Effect standard_atlasShadow_mapobject
{
	VertexShader = "VS_jomini_mapobject_shadow"
	PixelShader = "PS_jomini_mapobject_shadow"
	RasterizerState = ShadowRasterizerState
}

Effect standard_alpha_blend_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
	BlendState = "alpha_blend"
	DepthStencilState = "depth_test_no_write"
}
Effect standard_alpha_blendShadow_mapobject
{
	VertexShader = "VS_jomini_mapobject_shadow"
	PixelShader = "PS_jomini_mapobject_shadow_alphablend"
	RasterizerState = ShadowRasterizerState
}
Effect standard_alpha_to_coverage_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
	BlendState = "alpha_to_coverage"
	Defines = { "ALPHA_TO_COVERAGE" }
}
Effect standard_alpha_to_coverageShadow_mapobject
{
	VertexShader = "VS_jomini_mapobject_shadow"
	PixelShader = "PS_jomini_mapobject_shadow_alphablend"
	RasterizerState = ShadowRasterizerState
	Defines = { "ALPHA_TO_COVERAGE" }
}

Effect standard_colormap_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
	Defines = { "COLORMAP" }
}
Effect standard_colormapShadow_mapobject
{
	VertexShader = "VS_jomini_mapobject_shadow"
	PixelShader = "PS_jomini_mapobject_shadow"
	RasterizerState = ShadowRasterizerState
}
Effect standard_atlas_colormap_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
	Defines = { "COLORMAP" "ATLAS" }
}
Effect standard_atlas_colormapShadow_mapobject
{
	VertexShader = "VS_jomini_mapobject_shadow"
	PixelShader = "PS_jomini_mapobject_shadow"
	RasterizerState = ShadowRasterizerState
}


Effect standard_no_borders_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
	Defines = { "NO_BORDERS"  }
}
Effect standard_no_bordersShadow_mapobject
{
	VertexShader = "VS_jomini_mapobject_shadow"
	PixelShader = "PS_jomini_mapobject_shadow"	
	RasterizerState = ShadowRasterizerState
}
Effect standard_alpha_blend_no_borders_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
	BlendState = "alpha_blend"
	DepthStencilState = "depth_test_no_write"
	Defines = { "NO_BORDERS"  }
}
Effect standard_alpha_blend_no_bordersShadow_mapobject
{
	VertexShader = "VS_jomini_mapobject_shadow"
	PixelShader = "PS_jomini_mapobject_shadow_alphablend"	
	RasterizerState = ShadowRasterizerState
}




Effect flatmap_alpha_blend_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
	BlendState = "alpha_blend"
	DepthStencilState = "depth_test_no_write"
	RasterizerState = FlatmapRasterizerState
	Defines = { "NO_FOG" "FLATMAP" }	
}
Effect flatmap_alpha_blendShadow_mapobject
{
	VertexShader = "VS_jomini_mapobject_shadow"
	PixelShader = "PS_jomini_mapobject_shadow_alphablend"
	RasterizerState = ShadowRasterizerState
	Defines = { "NO_FOG" "FLATMAP" "FLATMAP" }	
}
Effect flatmap_alpha_blend_no_borders_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
	BlendState = "alpha_blend"
	DepthStencilState = "depth_test_no_write"
	RasterizerState = FlatmapRasterizerState
	Defines = { "NO_BORDERS" "NO_FOG" "FLATMAP"  }
}
Effect flatmap_alpha_blend_no_bordersShadow_mapobject
{
	VertexShader = "VS_jomini_mapobject_shadow"
	PixelShader = "PS_jomini_mapobject_shadow_alphablend"
	Defines = { "NO_FOG" "FLATMAP" }	
	RasterizerState = ShadowRasterizerState
}



Effect snap_to_terrain_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN"  }
}
Effect snap_to_terrainShadow_mapobject
{
	VertexShader = "VS_jomini_mapobject_shadow"
	PixelShader = "PS_jomini_mapobject_shadow"
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN" }
	RasterizerState = ShadowRasterizerState
}
Effect snap_to_terrain_alpha_to_coverage_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
	BlendState = "alpha_to_coverage"
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN" "ALPHA_TO_COVERAGE" }
}
Effect snap_to_terrain_alpha_to_coverageShadow_mapobject
{
	VertexShader = "VS_jomini_mapobject_shadow"
	PixelShader = "PS_jomini_mapobject_shadow_alphablend"
	RasterizerState = ShadowRasterizerState
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN" "ALPHA_TO_COVERAGE" }
}
Effect snap_to_terrain_alpha_to_coverage_colormap_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
	BlendState = "alpha_to_coverage"
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN" "COLORMAP" "ALPHA_TO_COVERAGE" }
}
Effect snap_to_terrain_alpha_to_coverage_colormapShadow_mapobject
{
	VertexShader = "VS_jomini_mapobject_shadow"
	PixelShader = "PS_jomini_mapobject_shadow_alphablend"
	RasterizerState = ShadowRasterizerState
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN" "ALPHA_TO_COVERAGE" }
}
Effect snap_to_terrain_treetrunk_mapobject
{
	VertexShader = "VS_mapobject"
	PixelShader = "PS_standard"
	Defines = { "PDX_MESH_SNAP_VERTICES_TO_TERRAIN" "WINDTRANSFORM" }
}

