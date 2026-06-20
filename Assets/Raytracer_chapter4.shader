
// Fra https://docs.unity3d.com/Manual/SL-VertexFragmentShaderExamples.html
//https://msdn.microsoft.com/en-us/library/windows/desktop/bb509640(v=vs.85).aspx
//https://msdn.microsoft.com/en-us/library/windows/desktop/ff471421(v=vs.85).aspx
// rand num generator http://gamedev.stackexchange.com/questions/32681/random-number-hlsl
// http://www.reedbeta.com/blog/2013/01/12/quick-and-easy-gpu-random-numbers-in-d3d11/
// https://docs.unity3d.com/Manual/RenderDocIntegration.html
// https://docs.unity3d.com/Manual/SL-ShaderPrograms.html

Shader "Unlit/SingleColor"
{
	
	    Properties
    {
//        _MainTex ("Texture", 2D) = "white" {}
        [Toggle] _boolchooser("myBool", Range(0, 1)) = 0 // [Toggle] creates a checkbox in gui and gives it 0 or 1
        _float3chooser("myFloat", Range(-1, 1)) = 0
        _colorchooser("myColor", color) = (1, 0, 0, 1)
        _vec4chooser("myVec4", Vector) = (0, 0, 0, 0)
		_ImageWidth ("Image Width", Float) = 400
		_AspectRatio ("Aspect Ratio", Float) = 1.7778 // ~16/9
		_ViewportHeight ("Viewport Height", Float) = 2.0
		_FocalLength ("Focal Length", Float) = 1.0
        // _texturechooser ("myTexture", 20) = "" {} // "" er for bildefil, {} er for options
    }
	    
		SubShader{ Pass	{
			
	CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag

		typedef vector <float, 3> vec3;  // to get more similar code to book
		typedef vector <fixed, 3> col3;

			// redeclaring gui inputs

            int _boolchooser;
            float _floatchooser;
            float4 _colorchooser;
            float4 _vec4chooser;
			float _ImageWidth;
			float _AspectRatio;
			float _ViewportHeight;
			float _FocalLength;
            //sampler2D _texturechooser;
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
	
	struct appdata
	{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
	};

	struct v2f
	{
		float2 uv : TEXCOORD0;
		float4 vertex : SV_POSITION;
	};
	
	v2f vert(appdata v)
	{
		v2f o;
		o.vertex = UnityObjectToClipPos(v.vertex);
		o.uv = v.uv;
		return o;
	}
	
	struct Ray 
	{
    	float3 origin;
    	float3 direction;
	};

	float3 RayColor(Ray r)
	{
		float3 unit_direction = normalize(r.direction);
		float t = 0.5 * (unit_direction.y + 1.0);
		float3 white = float3(1.0, 1.0, 1.0);
		float3 sky = float3(0.5, 0.7, 1.0);

		return (1.0 - t)*white + t*sky;
	}

	Ray MakeRay(float3 orig, float3 dir)
	{
    	Ray r;
    	r.origin = orig;
    	r.direction = dir;
    	return r;
	}
	
	float3 PointAtParameter(Ray r, float t)
	{
    	return r.origin + r.direction * t;
	}



	////////////////////////////////////////////////////////////////////////////////////////////////////////
		fixed4 frag(v2f i) : SV_Target
		{
			col3 col = _colorchooser;

			float image_height = _ImageWidth / _AspectRatio;
			
            if (image_height < 1.0)
            {
               image_height = 1.0;	                
            }
		
            float viewport_height = _ViewportHeight;
            float viewport_width  = viewport_height * _AspectRatio;
            float focal_length    = _FocalLength;

            float3 origin    = float3(0, 0, 0);
            float3 horizontal = float3(viewport_width, 0, 0);
            float3 vertical   = float3(0, viewport_height, 0);

            float3 lower_left_corner = origin - 0.5 * horizontal - 0.5 * vertical - float3(0,0,focal_length);

			float u = i.uv.x;
			float v = i.uv.y;

			Ray r;
			r.origin = origin;
			r.direction = lower_left_corner + (u * horizontal) + (v * vertical) - origin;
			float3 pixel_color = RayColor(r);

			return float4(pixel_color, 1.0);
		}
	////////////////////////////////////////////////////////////////////////////////////////////////////////


	ENDCG

		}
	}
}