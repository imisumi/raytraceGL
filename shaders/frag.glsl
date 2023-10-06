#version 330

#define USE_NEE
#define USE_VNDF
// BVH is actually slower
// #define USE_BVH

out vec4 fragColor;

// Previous frame
uniform sampler2D prevFrame;

// Camera properties
uniform vec2 resolution;

// Checkerboard pattern
// Set to -ve to disable
uniform float checkerboard;

// Constants
const float pi = 3.14159265;
const float inf = 99999999.0;
const float eps = 1e-5;

uniform vec3 u_camPosition;
uniform float u_smaples;
uniform mat4 _invView;
uniform mat4 _invProjection;

const float c_rayPosNormalNudge = 0.01f;
const float c_superFar = 10000.0f;
const float c_FOVDegrees = 90.0f;
const int c_numBounces = 8;
const int c_numRendersPerFrame = 1;
const float c_pi = 3.14159265359f;
const float c_twopi = 2.0f * c_pi;
const float c_minimumRayHitTime = 0.1f;

struct Ray
{
	vec3	origin;
	vec3	direction;
};

struct Sphere
{
	vec3 position;
	float radius;
	vec3 normal;
};

struct HitInfo
{
	float dist;
	vec3 normal;
	vec3 albedo;
	vec3 emissive;
};

bool sphere_intersection(in Ray ray, inout HitInfo info, in Sphere sphere)
{
	for (int i = 0; i < 1; i++)
	{
		vec3 offset = ray.origin - sphere.position;

		float a = dot(ray.direction, ray.direction);
		float b = 2.0 * dot(ray.direction, offset);
		float c = dot(offset, offset) - sphere.radius * sphere.radius;

		float discriminant = b * b - 4.0 * a * c;

		if (discriminant >= 0.0)
		{
			float dist = (-b - sqrt(discriminant)) / (2.0 * a);
			if (dist > 0.0 && dist < info.dist)
			{
				info.dist = dist;
				vec3 hitPoint = ray.origin + ray.direction * dist;
				info.normal = normalize(hitPoint - sphere.position);
				return true;
			}
		}
	}
	return false;
}

float ScalarTriple(vec3 u, vec3 v, vec3 w)
{
    return dot(cross(u, v), w);
}

bool TestQuadTrace(in Ray ray, inout HitInfo info, in vec3 a, in vec3 b, in vec3 c, in vec3 d)
{
    // calculate normal and flip vertices order if needed
    vec3 normal = normalize(cross(c-a, c-b));
    if (dot(normal, ray.direction) > 0.0f)
    {
        normal *= -1.0f;
        
		vec3 temp = d;
        d = a;
        a = temp;
        
        temp = b;
        b = c;
        c = temp;
    }
    
    vec3 p = ray.origin;
    vec3 q = ray.origin + ray.direction;
    vec3 pq = q - p;
    vec3 pa = a - p;
    vec3 pb = b - p;
    vec3 pc = c - p;
    
    // // determine which triangle to test against by testing against diagonal first
    vec3 m = cross(pc, pq);
    float v = dot(pa, m);
    vec3 intersectPos;
    if (v >= 0.0f)
    {
        // test against triangle a,b,c
        float u = -dot(pb, m);
        if (u < 0.0f)
			return false;
        float w = ScalarTriple(pq, pb, pa);
        if (w < 0.0f)
			return false;
        float denom = 1.0f / (u+v+w);
        u*=denom;
        v*=denom;
        w*=denom;
        intersectPos = u*a+v*b+w*c;
    }
    else
    {
        vec3 pd = d - p;
        float u = dot(pd, m);
        if (u < 0.0f) return false;
        float w = ScalarTriple(pq, pa, pd);
        if (w < 0.0f) return false;
        v = -v;
        float denom = 1.0f / (u+v+w);
        u*=denom;
        v*=denom;
        w*=denom;
        intersectPos = u*a+v*d+w*c;
    }
    
    float dist;
    if (abs(ray.direction.x) > 0.1f)
    {
        dist = (intersectPos.x - ray.origin.x) / ray.direction.x;
    }
    else if (abs(ray.direction.y) > 0.1f)
    {
        dist = (intersectPos.y - ray.origin.y) / ray.direction.y;
    }
    else
    {
        dist = (intersectPos.z - ray.origin.z) / ray.direction.z;
    }
    
	if (dist > c_minimumRayHitTime && dist < info.dist)
    {
		info.dist = dist;        
        info.normal = normal; 
		return true;
    }
    return false;
}


vec3 GetRayColor(Ray ray)
{
	HitInfo hitinfo;
	hitinfo.dist = c_superFar;
	Sphere sphere;

	vec3 ret = vec3(0.2078, 0.0549, 0.3137);

	sphere.position = vec3(-10.0, 0.0, 20.0);
	sphere.radius = 0.5;
	if (sphere_intersection(ray, hitinfo, sphere))
	{
		ret = vec3(0.702, 0.1333, 0.1333);
	}
	sphere.position.x  = 0.0;
	if (sphere_intersection(ray, hitinfo, sphere))
	{
		ret = vec3(0.1333, 0.5608, 0.2392);
	}
	sphere.position.x = 10.0;
	if (sphere_intersection(ray, hitinfo, sphere))
	{
		ret = vec3(0.1294, 0.1294, 0.5451);
	}

	vec3 A = vec3(-15.0f, -15.0f, 22.0f);
	vec3 B = vec3( 15.0f, -15.0f, 22.0f);
	vec3 C = vec3( 15.0f,  15.0f, 22.0f);
	vec3 D = vec3(-15.0f,  15.0f, 22.0f);
	if (TestQuadTrace(ray, hitinfo, A, B, C, D))
	{
		ret = vec3(0.3529, 0.3529, 0.3529);
	}
	return ret;
}

void main()
{
	vec4 fragCoord = gl_FragCoord;
	vec2 normalizedCoord = fragCoord.xy / resolution.xy;
	float aspectRatio = resolution.x / resolution.y;
	vec2 coord = normalizedCoord * 2.0 - 1.0;

	vec3 rayOrigin = u_camPosition;
	vec4 target = _invProjection * vec4(coord, 1.0, 1.0);
	vec3 rayDirection = vec3(_invView * vec4(normalize(vec3(target.xyz) / target.w), 0.0));

	vec3 prev = texture(prevFrame, fragCoord.xy / resolution.xy).rgb;

	Ray ray;
	ray.origin = rayOrigin;
	ray.direction = rayDirection;

	vec3 color = GetRayColor(ray);
	fragColor = vec4(color + prev, 1.0);
	// fragColor = vec4(rayDirection + prev, 1.0);
}

















// bool sphere_inter(Ray ray, float radius)
// {
// 	vec3 oc = ray.origin;
// 	float a = dot(ray.direction, ray.direction);
// 	float b = 2.0 * dot(ray.direction, oc);
// 	float c = dot(oc, oc) - radius * radius;

// 	float discriminant = b * b - 4.0 * a * c;

// 	return discriminant >= 0.0;
// }

// void main()
// {
// 	vec4 fragCoord = gl_FragCoord;
// 	vec2 normalizedCoord = fragCoord.xy / resolution.xy;
// 	float aspectRatio = resolution.x / resolution.y;
// 	vec2 coord = normalizedCoord * 2.0 - 1.0;

// 	vec3 rayOrigin = u_camPosition;
// 	vec4 target = _invProjection * vec4(coord, 1.0, 1.0);
// 	vec3 rayDirection = vec3(_invView * vec4(normalize(vec3(target.xyz) / target.w), 0.0));

// 	vec3 op;
// 	Ray ray;
// 	ray.origin = rayOrigin;
// 	ray.direction = rayDirection;
// 	if (sphere_inter(ray, 0.5))
// 		op = vec3(0.0, 1.0, 0.0);
// 	else
// 		op = vec3(rayDirection);
// 	vec3 prev;
// 	prev = texture(prevFrame, fragCoord.xy / resolution.xy).rgb;
// 	fragColor = vec4(op + prev, 1);
// }
