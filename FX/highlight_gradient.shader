Includes = {
	"cw/fullscreen_vertexshader.fxh"
	"cw/random.fxh"
	"jomini/jomini_colormap_constants.fxh"
}

ConstantBuffer( PdxConstantBuffer0 )
{	
	float2		KernelSize;
	int			NumSamples;
	float alignment_dummy;	
	float4		DiscSamples[8];
}

PixelShader =
{
	TextureSampler IndirectionMap
	{
		Ref = JominiProvinceColorIndirection
		MinFilter = "Point"
		MagFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}
	TextureSampler ProvinceColorTexture
	{
		Ref = JominiProvinceColor
		MagFilter = "Point"
		MinFilter = "Point"
		MipFilter = "Point"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}

	MainCode PixelShader
	{
		Input = "VS_OUTPUT_FULLSCREEN"
		Output = "PDX_COLOR"
		Code
		[[
			
			float2 RotateDisc( float2 Disc, float2 Rotate )
			{
				return float2( Disc.x * Rotate.x - Disc.y * Rotate.y, Disc.x * Rotate.y + Disc.y * Rotate.x );
			}
			PDX_MAIN
			{
				// Scan the map for pixels that have a highlight color with non-zero alpha.
				// The gradient's alpha will be the % of samples that have a highlight color.
				// Poisson disc sampling is used to cover a large area with relatively few samples.
				// To avoid recalculating the poisson offsets for each pixel we get a precalculated 
				// list of samples from the CPU, that each pixel can rotate randomly to avoid visible
				// artifacts that normally appear when they all sample using the same pattern.
				float Alpha = 0;
				float RandomAngle = CalcRandom( Input.uv ) * 3.14159 * 2.0;
				float2 Rotate = float2( cos( RandomAngle ), sin( RandomAngle ) );
				int Samples = (NumSamples+1) / 2;
				for( int i = 0; i < Samples; ++i )
				{
					float2 ColorIndex = PdxTex2DLod0( IndirectionMap, Input.uv + RotateDisc(DiscSamples[i].xy,Rotate) * KernelSize ).rg;
					Alpha += step( 1.0f/255.0f, PdxTex2DLoad0( ProvinceColorTexture, int2( ColorIndex * 255.0 + vec2(0.5f) + HighlightProvinceColorsOffset ) ).a );
					ColorIndex = PdxTex2DLod0( IndirectionMap, Input.uv + RotateDisc(DiscSamples[i].zw,Rotate) * KernelSize ).rg;
					Alpha += step( 1.0f/255.0f, PdxTex2DLoad0( ProvinceColorTexture, int2( ColorIndex * 255.0 + vec2(0.5f) + HighlightProvinceColorsOffset ) ).a );
				}
				
				Alpha /= Samples*2;
				return float4( Alpha, Alpha, 0, 1);
			}
		]]
	}
}

BlendState BlendState
{
	BlendEnable = no
}
Effect RenderGradient
{
	VertexShader = VertexShaderFullscreen
	PixelShader = PixelShader
}