
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
//        [Toggle] _boolchooser("myBool", Range(0, 1)) = 0 // [Toggle] creates a checkbox in gui and gives it 0 or 1
//        _float3chooser("myFloat", Range(-1, 1)) = 0
//        _colorchooser("myColor", color) = (1, 0, 0, 1)
//        _vec4chooser("myVec4", Vector) = (0, 0, 0, 0)
//		_ImageWidth ("Image Width", Float) = 400
//		_AspectRatio ("Aspect Ratio", Float) = 1.7778 // ~16/9
//		_ViewportHeight ("Viewport Height", Float) = 2.0
//		_FocalLength ("Focal Length", Float) = 1.0
        // _texturechooser ("myTexture", 20) = "" {} // "" er for bildefil, {} er for options
    	
    	_NumSamples ("Rays Per Pixel", Range(1,5000)) = 1000
        _MaxBounces ("Max Bounces", Range(1,60)) = 10
    	[Toggle] _ResetCameraPos("Default Camera Position", Range(0,1)) = 0
    	// camera position sliders
    	_CameraPositionX ("Camera Position X", Range(-10,10)) = 0
    	_CameraPositionY ("Camera Position Y", Range(-0.5,10)) = 0
    	_CameraPositionZ ("Camera Position Z", Range(-10,10)) = 0
    	// camera lookAt sliders.
    	_LookAtX ("LookAt Position X", Range(-10,10)) = 0
    	_LookAtY ("LookAt Position Y", Range(-10,10)) = 0
    	_LookAtZ ("LookAt Position Z", Range(-10,10)) = -1
        _SphereX ("Sphere X Offset", Range(-10,10)) = 0
        _GlassRefIdx ("Glass Refraction Index", Range(0.0,1.24)) = 1
    	_FuzzinessRightSphere ("Fuzziness Right Sphere", Range(0,1)) = 0
    }
	    
		SubShader{ Pass	{
			
	CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag

		typedef vector <float, 3> vec3;  // to get more similar code to book
		typedef vector <fixed, 3> col3;

		#define NUM_SPHERES 5

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

            // New slider inputs:
			int _ResetCameraPos;
			// camera positions
            float _CameraPositionX;
			float _CameraPositionY;
			float _CameraPositionZ;
            float _LookAtX;
			float _LookAtY;
			float _LookAtZ;

			float _NumSamples;
            float _MaxBounces;
            float _SphereX;
            float _GlassRefIdx;
			float _FuzzinessRightSphere;
		
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
		
	struct Interval
	{
	    float minVal;
	    float maxVal;
	};

	Interval MakeInterval(float mn, float mx)
	{
	    Interval i;
	    i.minVal = mn;
	    i.maxVal = mx;
	    return i;
	}

	bool IntervalContains(Interval i, float x)
	{
	    return (x >= i.minVal) && (x <= i.maxVal);
	}

	bool IntervalSurrounds(Interval i, Interval other)
	{
	    return (i.minVal <= other.minVal) && (i.maxVal >= other.maxVal);
	}

	Interval IntervalEmpty()
	{
	    return MakeInterval(1e20, -1e20);
	}
		
	Interval IntervalUniverse()
	{
	    return MakeInterval(-1e20, 1e20);
	}
	
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

	float3 RandomUnitVector(float2 rand2)
	{
	    float phi      = 2.0 * 3.14159 * rand2.x;
	    float cosTheta = 2.0 * rand2.y - 1.0;
	    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

	    return float3(
	        cos(phi) * sinTheta,
	        sin(phi) * sinTheta,
	        cosTheta
	    );
	}

	float3 RandomOnSphereSurface(float2 rand2)
	{
	    float phi      = 2.0 * 3.14159 * rand2.x;
	    float cosTheta = 1.0 - 2.0 * rand2.y;
	    float sinTheta = sqrt(1.0 - cosTheta*cosTheta);

	    return float3(
	        cos(phi) * sinTheta,
	        sin(phi) * sinTheta,
	        cosTheta
	    );
	}

	float3 RandomInHemisphere(float3 normal, float2 rand2)
	{
	    float3 in_sphere = RandomOnSphereSurface(rand2);
	    return (dot(in_sphere, normal) > 0.0) ? in_sphere : -in_sphere;
	}

	float3 RandomUnitVectorApprox(float2 uv)
	{
	    float3 p = float3(2.0 * uv.x - 1.0, 2.0 * uv.y - 1.0, 0.0);
	    return normalize(p);
	}

	float3 RandomUnitVectorReject(float2 uvSeed)
	{
	    for (int i = 0; i < 4; i++)
	    {
	        float2 uv = uvSeed + float2(i, i*13.123);
	        float3 p = float3(
	            frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453) * 2.0 - 1.0,
	            frac(sin(dot(uv, float2(39.4251, 11.877))) * 57231.1961) * 2.0 - 1.0,
	            frac(sin(dot(uv, float2(91.8892, 63.726))) * 91822.3361) * 2.0 - 1.0
	        );
	        float lensq = dot(p, p);
	        if (lensq < 1.0 && lensq > 1e-16)
	        {
	            return p / sqrt(lensq);
	        }
	    }
	    return float3(0,0,1);
	}

	struct Camera
	{
	    float3 origin;
	    float3 horizontal;
	    float3 vertical;
	    float3 lower_left_corner;
	    float3 u, v, w;
	    float lens_radius;
	};

	float Radians(float deg)
	{
		return deg * 3.14159 / 180.0;
	}

	Camera MakeCamera(float3 lookfrom, float3 lookat, float3 vup, float vfov, float aspect_ratio, float aperture, float focus_dist)
	{
	    Camera cam;

	    float theta = Radians(vfov);
	    float h = tan(theta * 0.5);
	    float viewport_height = 2.0 * h;
	    float viewport_width  = aspect_ratio * viewport_height;

	    cam.w = normalize(lookfrom - lookat);
	    cam.u = normalize(cross(vup, cam.w));
	    cam.v = cross(cam.w, cam.u);

	    cam.origin = lookfrom;
	    cam.horizontal = focus_dist * viewport_width  * cam.u;
	    cam.vertical   = focus_dist * viewport_height * cam.v;
	    cam.lower_left_corner = cam.origin - 0.5 * cam.horizontal - 0.5 * cam.vertical - focus_dist * cam.w;
	    cam.lens_radius = aperture * 0.5;
	    return cam;
	}

	float2 Rand(float2 uv)
	{
	    float2 hashVal = sin(float2(
	        dot(uv, float2(127.1, 311.7)),
	        dot(uv, float2(269.5, 183.3))
	    ));
	    return frac(hashVal * 43758.5453);
	}

	float3 Reflect(float3 v, float3 n)
	{
		return v - 2.0 * dot(v,n) * n;
	}

    float Schlick(float cosine, float ref_idx)
    {
        float r0 = (1.0 - ref_idx) / (1.0 + ref_idx);
        r0 = r0*r0;
        return r0 + (1.0 - r0) * pow((1.0 - cosine),5.0);
    }

	float3 Refract(float3 v, float3 n, float ni_over_nt)
    {
        float dt = dot(v, n);
        float discriminant = 1.0 - ni_over_nt * ni_over_nt * (1.0 - dt*dt);
        if(discriminant > 0.0)
        {
            return ni_over_nt * (v - n*dt) - n * sqrt(discriminant);
        }
        return float3(0,0,0);
    }
	
	struct Ray 
	{
    	float3 origin;
    	float3 direction;
	};

	struct HitRecord
	{
		float3 p;
		float3 normal;
		float t;
		bool front_face;

		int materialType;
		float3 albedo;
		float fuzz;
		float ref_idx;
	};

	bool HitSomething(Ray r, Interval ray_t, out HitRecord rec)
	{
	    return false;
	}

	struct Sphere
	{
		float3 center;
		float radius;
		int materialtype;
		float4 matproperties;
	};

	void SetFaceNormal(float3 ray_direction, float3 outward_normal, out bool front_face, out float3 normal)
	{
		front_face = (dot(ray_direction, outward_normal) < 0.0f);
		normal = front_face ? outward_normal : -outward_normal;
	}

	bool Scatter(HitRecord rec, float3 inDir, float2 randSeed, out float3 attenuation, out float3 scatterDir)
	{
		if (rec.materialType == 0)
		{
			float3 target = rec.p + rec.normal + RandomUnitVector(randSeed) - rec.p;
			attenuation = rec.albedo;
			scatterDir = target - rec.p;
			return true;
		}
		else if (rec.materialType == 1)
		{
			float3 reflected = Reflect(normalize(inDir), rec.normal);
			scatterDir = reflected + rec.fuzz * RandomUnitVector(randSeed);
			attenuation = rec.albedo;

			if (dot(scatterDir, rec.normal) <= 0.0)
			{
				attenuation = float3(0,0,0);
				scatterDir = float3(0,0,0);
				return false;
			}

			return true;
		}
		else if (rec.materialType == 2)
        {
            attenuation = float3(1,1,1);
            float3 unitDir = normalize(inDir);
			float refractionRatio = rec.front_face ? (1.0 / rec.ref_idx) : rec.ref_idx;
            float cosTheta = min(dot(-unitDir, rec.normal), 1.0);
            float sinTheta = sqrt(1.0 - cosTheta*cosTheta);
            bool cannotRefract = (refractionRatio * sinTheta) > 1.0;
            float reflectProb = Schlick(cosTheta, refractionRatio);

			float randomVal = Rand(randSeed).x;
            if(cannotRefract || randomVal < reflectProb)
            {
                scatterDir = Reflect(unitDir, rec.normal);
            }
            else
            {
                scatterDir = Refract(unitDir, rec.normal, refractionRatio);
            }
			
            return true;
        }
		attenuation = float3(0,0,0);
		scatterDir = float3(0,0,0);
		return false;
	}

	Ray GetRay(Camera cam, float s, float t)
	{
	    float3 offset = float3(0,0,0);

	    Ray r;
	    r.origin = cam.origin + offset;
	    r.direction = cam.lower_left_corner + s * cam.horizontal + t * cam.vertical - cam.origin - offset;
	    return r;
	}

	void GetSphere(int i, out Sphere sph)
	{
	    // Default
	    sph.center = float3(0,0,0);
	    sph.radius = 1.0;
	    sph.materialtype = 0;
	    sph.matproperties = float4(1,1,1,1);
		

		// ground sphere
		if (i == 0) { sph.center = float3( 0,-100.5, -1); sph.radius = 100; sph.materialtype = 0; sph.matproperties = float4(0.8, 0.8, 0.0, 0.3);}
		// center sphere
		else if (i == 1) { sph.center = float3( 0, 0, -1.2); sph.radius = 0.5; sph.materialtype = 0; sph.matproperties = float4(0.1, 0.2, 0.5, 0.3);}
		// left sphere
		else if (i == 2) { sph.center = float3(_SphereX, 0, -1); sph.radius = 0.5; sph.materialtype = 2; sph.matproperties = float4(1, 1, 1, _GlassRefIdx);}
		// left inner sphere
		else if (i == 3) { sph.center = float3(_SphereX, 0, -1); sph.radius = -0.4; sph.materialtype = 2; sph.matproperties = float4(1, 1, 1, _GlassRefIdx);}
		// right sphere
		else if (i == 4) { sph.center = float3( 1, 0, -1); sph.radius = 0.5; sph.materialtype = 1; sph.matproperties = float4(0.8, 0.6, 0.2, _FuzzinessRightSphere);}
	}		

	bool HitSphere(Sphere sphere, Ray r, Interval ray_t, out HitRecord rec)
	{
		rec.ref_idx = 1.0;
		
		float3 oc = r.origin - sphere.center;
		float a = dot(r.direction, r.direction);
		float h = dot(oc, r.direction);
		float c = dot(oc, oc) - sphere.radius*sphere.radius;
		float discriminant = h*h - a*c;
    
		if (discriminant < 0.0)
		{
			return false;
		}
		
		float sqrtD = sqrt(discriminant);
		
		float root = (-h - sqrtD) / a;
		if (root < ray_t.minVal || root > ray_t.maxVal)
		{
			root = (-h + sqrtD) / a;
			if (root < ray_t.minVal || root > ray_t.maxVal)
			{
				return false;
			}
		}
		
		rec.t = root;
		rec.p = r.origin + root * r.direction;
		float3 outward_normal = (rec.p - sphere.center) / sphere.radius;
		bool front_face;
		float3 normal;
		SetFaceNormal(r.direction, outward_normal, front_face, normal);
		rec.front_face = front_face;
		rec.normal = normal;

		rec.materialType = sphere.materialtype;
		rec.albedo = sphere.matproperties.xyz;
		rec.fuzz = sphere.matproperties.w;
		
		if (rec.materialType == 2)
		{
			rec.ref_idx = sphere.matproperties.w;
		}
		
		return true;
	}

	bool HitWorld(Ray r, Interval ray_t, out HitRecord rec)
    {
        HitRecord tempRec;
        bool hitAnything = false;
        float closestSoFar = ray_t.maxVal;

        for (int i = 0; i < NUM_SPHERES; i++)
        {
            Sphere sph;
        	GetSphere(i, sph);
        	
            if (HitSphere(sph, r, ray_t, tempRec))
            {
            	hitAnything = true;
                closestSoFar = tempRec.t;
            	rec = tempRec;
            	ray_t.maxVal = closestSoFar;
            }
        }
        return hitAnything;
    }

	float3 RayColor(Ray r, int maxDepth, float2 randSeed)
	{
		float3 color = float3(1,1,1);
		bool skyHit = false;

		// d: bouncecount.
	    for (int d = 0; d < maxDepth; d++)
	    {
	        HitRecord rec;
	        if (!HitWorld(r, MakeInterval(0.001f, 1e20f), rec))
	        {
	        	float3 unit_dir = normalize(r.direction);
	        	float t = 0.5 * (unit_dir.y + 1.0);
	        	float3 sky = lerp(float3(1,1,1), float3(0.5, 0.7, 1.0), t);

	        	color *= sky;
	        	skyHit = true;
	        	break;
	        }
	        else
	        {
	            float3 attenuation, scatterDir;
	            if (Scatter(rec, r.direction, randSeed + float2(d,0), attenuation, scatterDir))
	            {
	                color *= attenuation;
	                float offset = 0.0001f;
	                r.origin    = rec.p + rec.normal * offset;
	                r.direction = scatterDir;
	            }
	            else
	            {
	                color = float3(0,0,0);
	                break;
	            }
	        }
	    }
		if (!skyHit)
		{
			color = float3(0,0,0);
		}
	    return color;
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
		    float3 lookfrom = (_ResetCameraPos != 0) ? float3(0,0,0) : float3(_CameraPositionX, _CameraPositionY, _CameraPositionZ);
		    float3 lookat   = (_ResetCameraPos != 0) ? float3(0,0,-1) : float3(_LookAtX, _LookAtY, _LookAtZ);
		    float3 vup      = float3(0, 1, 0);
		    float vfov      = 90.0;
		    float aspect    = 1.7778;
		    float aperture  = 0.0;
		    float focusDist = 1.0;

			Camera cam = MakeCamera(lookfrom, lookat, vup, vfov, aspect, aperture, focusDist);

			float u = i.uv.x;
			float v = i.uv.y;

			Interval ray_t = MakeInterval(0.001f, 1e20f);

			Ray r = GetRay(cam, u, v);
			
			float3 finalColor = float3(0,0,0);
			int samples = (int)_NumSamples;
			int maxDepth = (int)_MaxBounces;
			for (int s = 0; s < samples; s++)
			{
				float2 seed = Rand(i.uv * float2(s, 0));
			    finalColor += RayColor(r, maxDepth, seed);
			}
			finalColor /= (float)samples;

			// Gamma correction:
			finalColor = sqrt(finalColor);

//			finalColor = pow(finalColor, 1.0 / 2.2);

			return float4(finalColor, 1.0);
		}
	////////////////////////////////////////////////////////////////////////////////////////////////////////


	ENDCG

		}
	}
}