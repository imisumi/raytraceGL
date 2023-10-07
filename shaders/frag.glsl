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
uniform float u_frames;
uniform mat4 _invView;
uniform mat4 _invProjection;

uniform int seedInit;
int seed = 0;

const float c_rayPosNormalNudge = 0.01f;
const float c_superFar = 10000.0f;
const float c_FOVDegrees = 90.0f;
const int c_numBounces = 8;
const int c_numRendersPerFrame = 1;
const float c_pi = 3.14159265359f;
const float c_twopi = 2.0f * c_pi;
const float c_minimumRayHitTime = 0.1f;

#define MAX_BOUNCES 5

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
	vec3 hitPoint;
	bool didHit;
};

bool	sphere_intersection(in Ray ray, inout HitInfo info, in Sphere sphere)
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
			info.didHit = true;
			info.dist = dist;
			info.hitPoint = ray.origin + ray.direction * dist;
			info.normal = normalize(info.hitPoint - sphere.position);
			return true;
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

float	RandomFloat(inout uint state)
{
	state = state * 747796405u + 2891336453u;
	uint result = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	result = (result >> 22u) ^ result;
	return float(result) / 4294967297.0f;
}

float	RandomValueNormalDistribution(inout uint state)
{
	float theta = 2 * 3.1415926 * RandomFloat(state);
	float rho = sqrt(-2 * log(RandomFloat(state)));
	return rho * cos(theta);
}

vec3 RandomUnitVector(inout uint state)
{
	float x = RandomValueNormalDistribution(state);
	float y = RandomValueNormalDistribution(state);
	float z = RandomValueNormalDistribution(state);
	return normalize(vec3(x, y, z));
}

vec3 RandomHemisphereDirection(vec3 normal, inout uint state)
{
	vec3 dir = RandomUnitVector(state);
	return dir * sign(dot(normal, dir));
}

void	scene_intersection(Ray ray, inout HitInfo info)
{
	Sphere sphere;

	vec3 A = vec3(-15.0f, -15.0f, 22.0f);
	vec3 B = vec3( 15.0f, -15.0f, 22.0f);
	vec3 C = vec3( 15.0f,  15.0f, 22.0f);
	vec3 D = vec3(-15.0f,  15.0f, 22.0f);
	if (TestQuadTrace(ray, info, A, B, C, D))
	{
		info.albedo = vec3(1.0f, 0.1f, 0.1f);
		info.emissive = vec3(0.0, 0.0, 0.0);
	}

	sphere.position = vec3(-10.0, 0.0, 20.0);
	sphere.radius = 0.5;
	if (sphere_intersection(ray, info, sphere))
	{
		info.albedo = vec3(0.1f, 1.0f, 0.1f);
		info.emissive = vec3(0.0, 0.0, 0.0);
	}
	sphere.position.x  = 0.0;
	if (sphere_intersection(ray, info, sphere))
	{
		info.albedo = vec3(0.1f, 0.1f, 1.0f);
		info.emissive = vec3(0.0, 0.0, 0.0);
	}
	sphere.position.x = 10.0;
	if (sphere_intersection(ray, info, sphere))
	{
		info.albedo = vec3(0.1294, 0.1294, 0.5451);
		info.emissive = vec3(0.0, 0.0, 0.0);
	}
	sphere.radius = 5.0;
	sphere.position = vec3(10.0f, 10.0f, 20.0f);
	if (sphere_intersection(ray, info, sphere))
	{
		info.albedo = vec3(0.0, 0.0, 0.0);
		info.emissive = vec3(1.0, 0.9, 0.7) * 100.0;
	}

}

vec3 GetRayColor(Ray ray, uint rngState)
{
	vec3 ret = vec3(0.0f, 0.0f, 0.0f);
	vec3 throughput = vec3(1.0f, 1.0f, 1.0f);

	vec3 ray_color = vec3(1.0f, 1.0f, 1.0f);

	for (int bounces = 0; bounces < 5; bounces++)
	{
		HitInfo	hitinfo;
		hitinfo.dist = c_superFar;
		scene_intersection(ray, hitinfo);

		if (hitinfo.dist == c_superFar)
		{
			// ret += throughput * vec3(0.2078, 0.0549, 0.3137);
			break;
		}
		// return hitinfo.albedo;

		ray.origin = (ray.origin + ray.direction * hitinfo.dist) + hitinfo.normal * c_rayPosNormalNudge;
		ray.direction = RandomHemisphereDirection(hitinfo.normal, rngState);

		vec3 color = hitinfo.albedo;
		vec3 emittedLight = hitinfo.emissive;
		ret += emittedLight * ray_color;
		ray_color *= color;

	}
	return ret;
}

void main()
{
	vec4 fragCoord = gl_FragCoord;
	vec2 normalizedCoord = fragCoord.xy / resolution.xy;
	float aspectRatio = resolution.x / resolution.y;
	vec2 coord = normalizedCoord * 2.0 - 1.0;
	// uint seed = uint(gl_FragCoord.x) + uint(gl_FragCoord.y) * 1000u;

	vec3 rayOrigin = u_camPosition;
	vec4 target = _invProjection * vec4(coord, 1.0, 1.0);
	vec3 rayDirection = vec3(_invView * vec4(normalize(vec3(target.xyz) / target.w), 0.0));

	vec3 prev = texture(prevFrame, fragCoord.xy / resolution.xy).rgb;

	

	vec2 uv = normalizedCoord;
	vec2 numPixels = resolution.xy;
	vec2 pixelCoord = uv * numPixels;
	uint pixelIndex = uint(pixelCoord.x) + uint(pixelCoord.y) * uint(numPixels.x);
	uint rngState = pixelIndex + uint(u_frames) * uint(719393);

	Ray ray;
	ray.origin = rayOrigin;
	ray.direction = rayDirection;

	vec3 color = GetRayColor(ray, rngState);
	color = clamp(color, 0.0, 1.0);
	fragColor = vec4(color + prev, 1.0);
	// fragColor = vec4(color, 1.0);
	// fragColor = vec4(rayDirection + prev, 1.0);


	// float r = RandomFloat(rngState);
	// float g = RandomFloat(rngState);
	// float b = RandomFloat(rngState);
	// fragColor = vec4(vec3(r, g, b) + prev, 1.0);
	// fragColor = vec4(vec3(r, g, b), 1.0);
}

// void main()
// {
// 	vec4 fragCoord = gl_FragCoord;
// 	vec2 uv = fragCoord.xy / resolution.xy;
// 	vec2 numPixels = resolution.xy;
// 	vec2 pixelCoord = uv * numPixels;
// 	uint pixelIndex = uint(pixelCoord.x) + uint(pixelCoord.y) * uint(numPixels.x);
// 	float c = float(pixelIndex) / float(numPixels.x * numPixels.y);
// 	uint rngState = pixelIndex + uint(u_frames) * uint(719393);

// 	vec3 prev = texture(prevFrame, fragCoord.xy / resolution.xy).rgb;

// 	float r = RandomFloat(rngState);
// 	float g = RandomFloat(rngState);
// 	float b = RandomFloat(rngState);
// 	fragColor = vec4(vec3(r, g, b) + prev, 1.0);
// 	// fragColor = vec4(vec3(r, g, b), 1.0);
// }




































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
