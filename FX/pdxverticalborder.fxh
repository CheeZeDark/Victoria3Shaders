
PixelShader =
{		
	Code
	[[
		// Settings for the vertical war border layers

		// Layer 1 - Vertical rays
		#define LAYER1_TOPALPHA_POSITION 1.05f
		#define LAYER1_TOPALPHA_CONTRAST 0.9f
		#define LAYER1_COLOR float3( 255.0f, 165.0f, 86.0f ) / 255.0f
		

		// Layer 2 - Embers
		#define LAYER2_TOPALPHA_POSITION 1.05f
		#define LAYER2_TOPALPHA_CONTRAST 0.3f
		
		#define ANIMATION_SPEED 0.5f
		#define MOVEMENT_SPEED 0.5f
		#define MOVEMENT_DIRECTION float2( -0.7f, 1.0f )

		#define PARTICLE_SIZE 0.02f

		#define PARTICLE_SCALE ( float2( 0.5f, 1.6f ) )
		#define PARTICLE_SCALE_VAR ( float2( 0.25f, 0.2f ) )

		#define PARTICLE_BLOOM_SCALE ( float2( 0.5f, 1.2f ) )
		#define PARTICLE_BLOOM_SCALE_VAR ( float2( 0.3f, 0.1f ) )

		#define SPARK_COLOR float3( 1.0f, 0.2f, 0.05f ) * 20.0f
		#define BLOOM_COLOR float3( 1.0f, 0.2f, 0.05f ) * 10.0f

		#define SIZE_MOD 1.25f
		#define ALPHA_MOD 0.82f
		#define LAYERS_COUNT 10

		// Layer 3 - Red fire
		#define LAYER3_TOPALPHA_POSITION 0.35f
		#define LAYER3_TOPALPHA_CONTRAST 0.9f

		#define LAYER3_COLOR float3( 206.0f, 15.0f, 15.0f ) / 255.0f
		
		#define LAYER3_FIRE_POSITION 0.0f
		#define LAYER3_FIRE_CONTRAST 8.0f
		#define LAYER3_FIRE_INTENSITY 8.0f
		#define LAYER3_FIRE_OPACITY 0.15f

		// Layer 4 - Yellow fire
		#define LAYER4_TOPALPHA_POSITION 0.75f
		#define LAYER4_TOPALPHA_CONTRAST 0.41f

		#define LAYER4_COLOR float3( 255.0f, 61.0f, 19.0f ) / 255.0f

		#define LAYER4_FIRE_POSITION 0.0f
		#define LAYER4_FIRE_CONTRAST 3.45f
		#define LAYER4_FIRE_INTENSITY 10.0f
		#define LAYER4_FIRE_INNER_INTENSITY 15.0f
		#define LAYER4_FIRE_INNER_POSITION 0.31f
		#define LAYER4_FIRE_INNER_CONTRAST 0.15f
		#define LAYER4_FIRE_OPACITY 0.08f
	]]
}
