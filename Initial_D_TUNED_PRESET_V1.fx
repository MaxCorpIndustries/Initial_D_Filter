/*------------------.
| :: Description :: |
'-------------------/

    DISCLAIMER:
	
	
	The purpose of this """" shader """" is to essentially compile several of the shaders that get offered to be installed when reshade is installed.
	
	Rather than sharing a general preset .ini file, I've found that I can instead fine tune these shaders, their value limits, and the png files they use to 
	make a specialized "shader" in the Reshade menu that will generate a better "initial D" manga comic style then I could do with the default settings in these shaders.
	
	CREDITS (are repeated at the start of the reshade shader too):
	----------------------------------------------------------------
	Used for speed lines:
	
		SirCobra (CobraFX):
				- Gravity
				- GravityCS
	----------------------------------------------------------------			
	Used for the cell shader effect:
	
		Daodan317081:
			- Comic
			
		MMJuno (RS RetroArch):
			- Cel Shader
	----------------------------------------------------------------	
	Used for the Manga onomatopoeia:
	
		CeeJa:
			- DefaultLayer
	----------------------------------------------------------------	
	Used to "worsen" the look of the game to emulate printed comics:
	
		luluco250 (FX Shaders):
			- Unsharp
			
		Lord Of Lunacy (InsaneShaders):
			- Halftone
			
		prod80 (Bas Veth):
			- D80 04 Contrast Brightness Saturation

		VileR (RS RetroArch):
			- EGA Filter
	----------------------------------------------------------------	
	
    License: MIT

*/
	

// Defines

#define COBRA_GRV_VERSION "0.2.2"
#define COBRA_GRV_UI_GENERAL "\n / General Options /\n"
#define COBRA_GRV_UI_DEPTH "\n /  Depth Options  /\n"
#define COBRA_GRV_UI_COLOR "\n /  Color Options  /\n"

#ifndef M_PI
    #define M_PI 3.1415927
#endif

#define ENABLE_RED (1 << 0)
#define ENABLE_GREEN (1 << 1)
#define ENABLE_BLUE (1 << 2)
#define ENABLE_ALPHA (1 << 3)

// Includes
#include "Reshade.fxh"

// Shader Start

// Namespace Everything!

namespace MAIN_TESTSPACE
{
	// GRAVITY UI 
	//----------------------------------------------------
	
	//Gravity Intensity Slider 
    uniform float UI_GravityIntensity <
        ui_label     = " Gravity Intensity";
        ui_type      = "slider";
        ui_spacing   = 2;
        ui_min       = 0.00;
        ui_max       = 1.00;
        ui_step      = 0.01;
        ui_tooltip   = "Gravity strength. Higher values look cooler but increase the computation time by a lot!";
        ui_category  = COBRA_GRV_UI_GENERAL;
    >                = 0.50;
	
	//Gravity RNG 
    uniform float UI_GravityRNG <
        ui_label     = " Gravity RNG";
        ui_type      = "slider";
        ui_min       = 0.01;
        ui_max       = 0.99;
        ui_step      = 0.02;
        ui_tooltip   = "Changes the random intensity of each pixel.";
        ui_category  = COBRA_GRV_UI_GENERAL;
    >                = 0.75;

	//Gravity Focus Range Depth
    uniform float UI_FocusRangeDepth <
        ui_label     = " Focus Range";
        ui_type      = "slider";
        ui_min       = 0.0;
        ui_max       = 1.000;
        ui_step      = 0.001;
        ui_tooltip   = "The depth range around the manual focus which should still be in focus.";
        ui_category  = COBRA_GRV_UI_DEPTH;
    >                = 1.000;

	//Gravity Focus Edge Depth
    uniform float UI_FocusEdgeDepth <
        ui_label     = " Focus Fade";
        ui_type      = "slider";
        ui_min       = 0.000;
        ui_max       = 1.000;
        ui_tooltip   = "The smoothness of the edge of the focus range. Range from 0.0, which means sudden\ntransition, till 1.0, which means the effect is smoothly fading towards camera and horizon.";
        ui_step      = 0.001;
        ui_category  = COBRA_GRV_UI_DEPTH;
    >                = 0.020;


    uniform bool UI_UseImage <
        ui_label     = " Use Image";
        ui_tooltip   = "Changes the RNG to the input image called gravityrng.png located in the Textures folder.\nYou can change the image for your own RNG as long as the name and resolution stay the same.";
        ui_category  = COBRA_GRV_UI_GENERAL;
    >                = false;

	//Gravity BUFFER END
    uniform int UI_BufferEnd <
        ui_type     = "radio";
        ui_spacing  = 2;
        ui_text     = " Shader Version: " COBRA_GRV_VERSION;
        ui_label    = " ";
    > ;

	// END OF GRAVITY  
	//----------------------------------------------------
	



    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    //                                         Textures & Samplers
    //
    ////////////////////////////////////////////////////////////////////////////////////////////////////////


	//GRAVITY  
	//----------------------------------------------------
	
	//Gravity DIST MAP
    texture TEX_GravityDistanceMap
    {
        Width  = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = R16F;
    };

	//Gravity SEED GEN
    texture TEX_GravityCurrentSeed
    {
        Format = R16F;
    };

	//Gravity PNG MAP 
    texture TEX_GravitySeedMapExt < source = "gravity_noise.png";
    >
    {
        Width  = 1920;
        Height = 1080;
        Format = RGBA8;
    };

    // raw depth, CoC,  GravitySeed, reserved
    texture TEX_GravityBuf
    {
        Width  = BUFFER_WIDTH;
        Height = BUFFER_HEIGHT;
        Format = RGBA16F;
    };
	
	// END OF GRAVITY  
	//----------------------------------------------------


    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    //                                           Samplers
    //
    ////////////////////////////////////////////////////////////////////////////////////////////////////////

	// GRAVITY
	//----------------------------------------------------
    
    sampler2D SAM_GravityBuf { Texture = TEX_GravityBuf; };
    sampler2D SAM_GravityDistanceMap { Texture = TEX_GravityDistanceMap; };
    sampler2D SAM_GravityCurrentSeed { Texture = TEX_GravityCurrentSeed; };
    sampler2D SAM_GravitySeedMapExt { Texture = TEX_GravitySeedMapExt; };

	// END OF GRAVITY  
	//----------------------------------------------------

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    //                                           Helper Functions
    //
    ////////////////////////////////////////////////////////////////////////////////////////////////////////

	// GRAVITY
	//----------------------------------------------------

    //GRAVITY Calculate Focus Intensity
    float check_focus(float2 texcoord : TEXCOORD)
    {
        float4 col_val            = tex2D(ReShade::BackBuffer, texcoord);
        float depth               = ReShade::GetLinearizedDepth(texcoord);
		const float FULL_RANGE    = UI_FocusRangeDepth + UI_FocusEdgeDepth;
        texcoord.x                = (texcoord.x) * ReShade::ScreenSize.x;
        texcoord.y                = (texcoord.y) * ReShade::ScreenSize.y;
        float fov_diff            = sqrt((texcoord.x * texcoord.x) + (texcoord.y * texcoord.y));
        float depth_diff          = abs(depth);
        float coc_val             = (1 - saturate((depth_diff > FULL_RANGE) ? 1.0 : smoothstep(UI_FocusRangeDepth, FULL_RANGE, depth_diff)));
        return ((distance(col_val.rgb, float3(0.0, 0.0, 0.0).rgb) < 1.74) ? coc_val : 0.0);
    }

    //GRAVITY calculate Mandelbrot Seed
    // inspired by http://nuclear.mutantstargoat.com/articles/sdr_fract/
    float mandelbrot_rng(float2 texcoord : TEXCOORD)
    {
        const float2 CENTER = float2(0.675, 0.46);                           // an interesting center at the mandelbrot for our zoom
        const float ZOOM    = 0.033 * UI_GravityRNG;                         // smaller numbers increase zoom
        const float AR      = ReShade::ScreenSize.x / ReShade::ScreenSize.y; // format to screenspace
        float2 z, c;
        c.x = AR * (texcoord.x - 0.5) * ZOOM - CENTER.x;
        c.y = (texcoord.y - 0.5) * ZOOM - CENTER.y;
        // c = float2(AR,1.0)*(texcoord-0.5) * ZOOM - CENTER;
        int i;
        z = c;

        for (i = 0; i < 100; i++)
        {
            float x = z.x * z.x - z.y * z.y + c.x;
            float y = 2 * z.x * z.y + c.y;
            if ((x * x + y * y) > 4.0)
                break;
            z.x = x;
            z.y = y;
        }

        const float intensity = 1.0;
        return saturate(((intensity * (i == 100 ? 0.0 : float(i)) / 100.0) - 0.8) / 0.22);
    }

    //GRAVITY Calculates the maximum Distance Map
    // For every pixel in GravityIntensity: If GravityIntensity*mandelbrot > j*offset.y : set new real max distance
    float distance_main(float2 texcoord : TEXCOORD)
    {
        float real_max_distance = 0.0;
        const float2 OFFSET     = float2(0.0, BUFFER_RCP_HEIGHT);
        int iterations          = round(min(texcoord.y, UI_GravityIntensity) * BUFFER_HEIGHT);
        int j;

        for (j = 0; j < iterations; j++)
        {

            float rng_value        = tex2Dlod(SAM_GravityBuf, float4(texcoord - j * OFFSET, 0, 1)).b;
            float tex_distance_max = UI_GravityIntensity * rng_value;
            if ((tex_distance_max) > (j * OFFSET.y)) // @TODO optimize, avoid conditionals
            {
                real_max_distance = j * OFFSET.y; // new max threshold
            }
        }
        return real_max_distance;
    }

    //GRAVITY Applies Gravity to the Pixels recursively
    float4 gravity_main(float4 vpos, float2 texcoord : TEXCOORD)
    {
        float real_max_distance = tex2Dfetch(SAM_GravityDistanceMap, vpos.xy).r;
        int iterations          = round(real_max_distance * BUFFER_HEIGHT);

        vpos.z            = 0;
        float4 sample_pos = vpos;
        for (float depth = tex2Dfetch(SAM_GravityBuf, vpos.xy).x;
             vpos.z < iterations; ++vpos.z, --vpos.y)
        {
            float4 samp = tex2Dfetch(SAM_GravityBuf, vpos.xy);
            samp.w *= samp.z;

            [flatten] if (!any(samp <= float4(depth - 0, 0.01, 0.05, vpos.z)))
            {
                sample_pos = vpos;
                sample_pos.z /= samp.w;
                depth = samp.x;
            }
        }

        float4 col_fragment = tex2Dfetch(ReShade::BackBuffer, sample_pos.xy);
        return lerp(col_fragment, float4(float3(0, 0, 0), 1.0), sample_pos.z * 1000);
    }

	//GRAVITY rng change
    float rng_delta()
    {
        const float OLD_RNG = tex2Dfetch(SAM_GravityCurrentSeed, (0).xx).x;
        const float NEW_RNG = UI_GravityRNG + 1 * 0.01 + UI_GravityIntensity;
        return OLD_RNG - NEW_RNG;
    }
	
	// END OF GRAVITY  
	//----------------------------------------------------	

    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    //                                              Shaders
    //
    ////////////////////////////////////////////////////////////////////////////////////////////////////////


	//GRAVITY  
	//----------------------------------------------------	
	
    void VS_GenerateRNG(uint vid : SV_VERTEXID, out float4 pos : SV_POSITION, out float2 uv : TEXCOORD)
    {
        PostProcessVS(vid, pos, uv);
        pos.xy *= abs(rng_delta()) > 0.005;
    }

    // RNG MAP
    void PS_GenerateRNG(float4 vpos : SV_Position, float2 texcoord : TEXCOORD, out float4 fragment : SV_Target)
    {
        float value = tex2D(SAM_GravitySeedMapExt, texcoord).r;
        value       = saturate((value - 1 + UI_GravityRNG) / UI_GravityRNG);
        fragment    = UI_UseImage? value : mandelbrot_rng(texcoord);
    }

    void VS_GenerateDistance(uint vid : SV_VERTEXID, out float4 pos : SV_POSITION, out float2 uv : TEXCOORD)
    {
        PostProcessVS(vid, pos, uv);
        pos.xy *= abs(rng_delta()) > 0.005;
    }

    // DISTANCE MAP
    void PS_GenerateDistance(float4 vpos : SV_Position, float2 texcoord : TEXCOORD, out float fragment : SV_Target)
    {
        fragment = distance_main(texcoord);
    }

    // COC + SEED
    void PS_GenerateCoC(float4 vpos : SV_Position, float2 texcoord : TEXCOORD, out float4 fragment : SV_Target)
    {
        vpos.w      = 0;
        fragment.x  = -ReShade::GetLinearizedDepth(texcoord);
        fragment.y  = check_focus(texcoord);
        fragment.zw = UI_GravityIntensity * fragment.y * BUFFER_HEIGHT;
    }

    void PS_UpdateRNGSeed(float4 vpos : SV_Position, float2 texcoord : TEXCOORD, out float fragment : SV_Target)
    {
        fragment = UI_GravityRNG + 1 * 0.01 + UI_GravityIntensity;
    }

    // MAIN FUNCTION
    void PS_Gravity(float4 vpos : SV_Position, float2 texcoord : TEXCOORD, out float4 outFragment : SV_Target)
    {
        vpos.w      = 0;
        outFragment = gravity_main(vpos, texcoord);
    }

    // PRECALC
    void VS_GenerateRNG2(uint vid : SV_VERTEXID, out float4 pos : SV_POSITION, out float2 uv : TEXCOORD)
    {
        PostProcessVS(vid, pos, uv);
        pos.xy *= true;
    }

    void VS_GenerateDistance2(uint vid : SV_VERTEXID, out float4 pos : SV_POSITION, out float2 uv : TEXCOORD)
    {
        PostProcessVS(vid, pos, uv);
        pos.xy *= true;
    }

	//END OF GRAVITY  
	//----------------------------------------------------	


    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    //                                             Techniques
    //
    ////////////////////////////////////////////////////////////////////////////////////////////////////////

	//GRAVITY  
	//----------------------------------------------------

    technique TECH_PreGravity <
        hidden     = true;
        enabled    = true;
        timeout    = 1000;
    >
    {
        pass GenerateRNG
        {
            VertexShader          = VS_GenerateRNG2;
            PixelShader           = PS_GenerateRNG;
            RenderTarget          = TEX_GravityBuf;
            RenderTargetWriteMask = ENABLE_BLUE;
        }

        pass GenerateDistance
        {
            VertexShader = VS_GenerateDistance2;
            PixelShader  = PS_GenerateDistance;
            RenderTarget = TEX_GravityDistanceMap;
        }

        pass GenerateCoC
        {
            VertexShader          = PostProcessVS;
            PixelShader           = PS_GenerateCoC;
            RenderTarget          = TEX_GravityBuf;
            RenderTargetWriteMask = ENABLE_RED | ENABLE_GREEN | ENABLE_ALPHA;
        }
    }

    technique TECH_Gravity <
        ui_label     = "MAIN_TESTSPACE";
        ui_tooltip   = "------About-------\n"
                       "TEST 1 \n"
                       "You can filter the affected pixels by depth and by color.\n"
                       "It uses a custom seed (currently the Mandelbrot set) to determine the intensity of each pixel.\n"
                       "Make sure to also test out the texture-RNG variant with the picture 'gravityrng.png' provided\n"
                       "in the Textures folder. You can replace the texture with your own picture, as long as it\n"
                       "is 1920x1080, RGBA8 and has the same name. Only the red-intensity is taken. So either use red\n"
                       "images or greyscale images.\n"
                       "The effect is quite resource consuming. On large resolutions, check out Gravity_CS.fx instead.\n\n"
                       "Version:    " COBRA_GRV_VERSION "\nAuthor:     SirCobra\nCollection: CobraFX\n"
                       "            https://github.com/LordKobra/CobraFX";
    >
    {
        pass GenerateRNG
        {
            VertexShader          = VS_GenerateRNG;
            PixelShader           = PS_GenerateRNG;
            RenderTarget          = TEX_GravityBuf;
            RenderTargetWriteMask = ENABLE_BLUE;
        }

        // dist to max scather point.
        pass GenerateDistance
        {
            VertexShader = VS_GenerateDistance;
            PixelShader  = PS_GenerateDistance;
            RenderTarget = TEX_GravityDistanceMap;
        }

        // also populate x with raw depth.
        pass GenerateCoC
        {
            VertexShader          = PostProcessVS;
            PixelShader           = PS_GenerateCoC;
            RenderTarget          = TEX_GravityBuf;
            RenderTargetWriteMask = ENABLE_RED | ENABLE_GREEN | ENABLE_ALPHA;
        }

        pass UpdateRNGSeed
        {
            VertexShader = PostProcessVS;
            PixelShader  = PS_UpdateRNGSeed;
            RenderTarget = TEX_GravityCurrentSeed;
        }

        pass ApplyGravity
        {
            VertexShader = PostProcessVS;
            PixelShader  = PS_Gravity;
        }
    }
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
}
// Shader End
