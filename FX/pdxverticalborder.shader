Includes = {
	"jomini/jomini_vertical_border.fxh"
	"cw/utility.fxh"
	"fog_of_war.fxh"
	"distance_fog.fxh"
	"pdxverticalborder.fxh"
}

PixelShader =
{		
	Code
	[[

		// Cell center from point on the grid
		float2 VoronoiPointFromRoot( in float2 root, in float deg )
		{
			float2 p = Hash2_2( root ) - 0.5f;
			float s = sin( deg );
			float c = cos( deg );
			p = mul( Create2x2( s, c, -c,  s ), p ) * 0.66f;
			p += root + 0.5f;
			return p;
		}

		// Voronoi cell point rotation degrees
		float DegFromRootUV( in float2 uv )
		{
			return GlobalTime * ANIMATION_SPEED * ( Hash1_2( uv ) - 0.5f ) * 2.0f;   
		}

		float2 RandomAround2_2( in float2 p, in float2 range, in float2 uv )
		{
			return p + ( Hash2_2( uv ) - 0.5 ) * range;
		}

		float4 ApplyVerticalBordersFog( float4 Diffuse, float3 WorldSpacePos )
		{
			Diffuse.rgb = ApplyFogOfWar( Diffuse.rgb, WorldSpacePos, FogOfWarAlpha );
			Diffuse.rgb = GameApplyDistanceFog( Diffuse.rgb, WorldSpacePos );
			Diffuse.a *= Alpha;
			
			return Diffuse;
		}

		float3 FireParticles( in float2 uv, in float2 originalUV )
		{
			float3 particles = vec3( 0.0f );
			float2 rootUV = floor( uv );
			float deg = DegFromRootUV( rootUV );
			float2 pointUV = VoronoiPointFromRoot( rootUV, deg );
			float dist = 2.0f;
			float distBloom = 0.0f;
		
			// UV manipulation for the faster particle movement
			float2 tempUV = uv + ( Noise2_2( uv * 2.0f ) - 0.5f ) * 0.1f;
			tempUV += -( Noise2_2( uv * 3.0f + GlobalTime ) - 0.5f ) * 0.07f;

			// Sparks sdf
			dist = length( Rotate( tempUV - pointUV, 0.7f ) * RandomAround2_2( PARTICLE_SCALE, PARTICLE_SCALE_VAR, rootUV ) );
			
			// Bloom sdf
			distBloom = length( Rotate( tempUV - pointUV, 0.7f ) * RandomAround2_2( PARTICLE_BLOOM_SCALE, PARTICLE_BLOOM_SCALE_VAR, rootUV ) );

			// Add sparks
			particles += ( 1.0f - smoothstep(PARTICLE_SIZE * 0.6f, PARTICLE_SIZE * 1.0f, dist) ) * SPARK_COLOR;
			
			// Add bloom
			particles += pow( ( 1.0f - smoothstep(0.0f, PARTICLE_SIZE * 4.0f, distBloom ) ) * 1.0, 3.0 ) * BLOOM_COLOR;

			// Upper disappear curve randomization
			float border = ( Hash1_2( rootUV ) - 0.5f ) * 1.0f;
			float disappear = 1.0f - smoothstep( border, border + 0.05f, 1.0f - originalUV.y );
			
			// Lower appear curve randomization
			border = ( Hash1_2( rootUV + 0.214f ) ) * 0.2f;
			float appear = smoothstep( border, border + 0.1f, 1.0f - originalUV.y );
			
			return particles * disappear * appear;
		}

		//Layering particles to imitate 3D view
		float3 LayeredParticles(in float2 uv, in float sizeMod, in float alphaMod, in int layers, in float smoke) 
		{ 
			float3 particles = vec3( 0 );
			float size = 1.0;
			float alpha = 1.0;
			float2 offset = float2( 0.0f, 0.0f );
			float2 noiseOffset;
			float2 bokehUV;
			
			for ( int i = 0; i < layers; i++ )
			{
				// Particle noise movement
				noiseOffset = ( Noise2_2( uv * size * 2.0 + 0.5 ) - 0.5 ) * 0.1f;
				
				// UV with applied movement
				bokehUV = ( uv * size + GlobalTime * MOVEMENT_DIRECTION * MOVEMENT_SPEED ) + offset + noiseOffset; 
				
				// Adding particles	
				particles += FireParticles( bokehUV, uv ) * alpha * ( ( float( i ) / float( layers ) ) );
				
				// Moving uv origin to avoid generating the same particles
				offset += Hash2_2( float2( alpha, alpha ) );
				
				// Next layer modification
				alpha *= alphaMod;
				size *= sizeMod;
			}
			
			return particles;
		}
	]]
	
	MainCode PixelShader_1x
	{
		Input = "VS_OUTPUT_PDX_BORDER"
		Output = "PDX_COLOR"
		Code
		[[	
			PDX_MAIN
			{
				float4 TexColor0 = PdxTex2D( BorderTexture0, Input.UV0 );
				float3 Diffuse = CalculateLayerColor( TexColor0.rgb, Color.rgb );
				
				return ApplyVerticalBordersFog( float4( Diffuse, TexColor0.a ), Input.WorldSpacePos );
			}
		]]
	}

	MainCode PixelShader_4x
	{
		Input = "VS_OUTPUT_PDX_BORDER"
		Output = "PDX_COLOR"
		Code
		[[			
			PDX_MAIN
			{
				// Find control settings in pdxverticalborder.fxh
				// Alpha
				float FadeDistance = min( 15.0f, Input.DistanceToStart + Input.DistanceToEnd );
				float EdgeFade = saturate( Input.DistanceToStart / FadeDistance ) * saturate( Input.DistanceToEnd / FadeDistance );
				float EdgeAlpha = saturate( pow( EdgeFade * 1.0f, 1.2f ) );

				// -----
				// Layer 1
				float TopAlpha1 = LevelsScan( Input.UV0.y, LAYER1_TOPALPHA_POSITION, LAYER1_TOPALPHA_CONTRAST );

				float ray1 = RayValue( Input.UV0, 31.0f, -0.4f, 0.3f );
				float ray2 = RayValue( Input.UV0, 23.0f, 0.1f, 0.2f );
				float ray3 = RayValue( Input.UV0, 33.0f, -0.05f, 0.1f );
				float ray4 = RayValue( Input.UV0, 21.0f, 0.5f, 0.1f );
				float rayComposite = ray1 + ray2 + ray3 + ray4;
				float3 Layer1Color = LAYER1_COLOR;
				float Layer1Alpha = saturate( rayComposite * TopAlpha1 );

				// -----
				// Layer 2
				float TopAlpha2 = LevelsScan( Input.UV0.y, LAYER2_TOPALPHA_POSITION, LAYER1_TOPALPHA_CONTRAST );
				float3 Layer2Color = saturate( LayeredParticles( Input.UV0, SIZE_MOD, ALPHA_MOD, LAYERS_COUNT, 1.0 ) );
				float Layer2Alpha = ( (Layer2Color.r + Layer2Color.g + Layer2Color.b ) / 3 ) * TopAlpha2;

				// -----
				// Layer 3
				float TopAlpha3 = LevelsScan( Input.UV0.y, LAYER3_TOPALPHA_POSITION, LAYER3_TOPALPHA_CONTRAST );

				float Layer3Alpha = PdxTex2D( BorderTexture2, float2( Input.UV2.x / 1.0f, Input.UV2.y ) ).a;
				Layer3Alpha = LevelsScan( Layer3Alpha, LAYER3_FIRE_POSITION, LAYER3_FIRE_CONTRAST );
				Layer3Alpha *= TopAlpha3;
				
				Layer3Alpha = Overlay( Layer3Alpha, 0.0f );
				Layer3Alpha = saturate( Layer3Alpha * LAYER3_FIRE_OPACITY );

				float3 Layer3Color = LAYER3_COLOR;
				Layer3Color *= LAYER3_FIRE_INTENSITY;				

				// -----
				// Layer 4
				float TopAlpha4 = LevelsScan( Input.UV0.y, LAYER4_TOPALPHA_POSITION, LAYER4_TOPALPHA_CONTRAST );
				float Layer4Alpha = PdxTex2D( BorderTexture3, float2( Input.UV3.x / 1.0f, Input.UV3.y ) * 1.5f + 0.5f ).a;
				Layer4Alpha = LevelsScan( Layer4Alpha, LAYER4_FIRE_POSITION, LAYER4_FIRE_CONTRAST );
				Layer4Alpha *= TopAlpha4;
				Layer4Alpha = Overlay( Layer4Alpha, 0.0f );

				float InnerIntensity = LevelsScan( Layer4Alpha, LAYER4_FIRE_INNER_POSITION, LAYER4_FIRE_INNER_CONTRAST ) * LAYER4_FIRE_INNER_INTENSITY;

				Layer4Alpha = saturate( Layer4Alpha * LAYER4_FIRE_OPACITY );

				float3 Layer4Color = LAYER4_COLOR;
				Layer4Color *= LAYER4_FIRE_INTENSITY + InnerIntensity;

				// -----
				// Color layers composite
				float4 Composite = AlphaBlend_AOverB( float4( Layer1Color, Layer1Alpha ), float4( Layer2Color, Layer2Alpha ) );
				Composite = AlphaBlend_AOverB( Composite, float4( Layer3Color, Layer3Alpha ) );
				Composite = AlphaBlend_AOverB( Composite, float4( Layer4Color, Layer4Alpha ) );

				float3 HSV_ = RGBtoHSV( Composite.rgb );
				HSV_.x += 0.0f;		// Hue
				HSV_.y *= 1.05f; 	// Saturation
				HSV_.z *= 3.0f;		// Value
				Composite.rgb = HSVtoRGB( HSV_ ); 

				Composite.a *= EdgeAlpha * ( 1.0f - FlatMapLerp );
				return ApplyVerticalBordersFog( float4( Composite ), Input.WorldSpacePos );
			}
		]]
	}
}

Effect VerticalBorder_1x
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShader_1x"
}

Effect VerticalBorder_4x
{
	VertexShader = "VertexShader"
	PixelShader = "PixelShader_4x"
	Defines = { "PDX_BORDER_UV1" "PDX_BORDER_UV2" "PDX_BORDER_UV3" }
}