#include <metal_stdlib>
using namespace metal;

struct PointData
{
    float4 color;
    float2 pos;
    float size;
};

struct PointVertexOut
{
    float4 position [[position]];
    float4 color;
    float size [[point_size]];
};

vertex PointVertexOut pointVtxFn(
    uint vertexID [[vertex_id]],
    constant PointData *pointData [[buffer(0)]],
    constant float4x4 &transform [[buffer(1)]])
{
    PointVertexOut v_out;
    float4 pos = float4(pointData[vertexID].pos.xy, 0.0, 1.0);
    v_out.position = transform * pos;
    v_out.color = pointData[vertexID].color;
    v_out.size = pointData[vertexID].size;
    return v_out;
}

fragment float4 pointFragFn(PointVertexOut in [[stage_in]])
{
    return in.color;
}

struct RectData
{
    float4 color;
    float2 pos;
};

struct RectVertexOut
{
    float4 position [[position]];
    float4 color;
};

vertex RectVertexOut rectVtxFn(
    uint vertexID [[vertex_id]],
    constant RectData *rectData [[buffer(0)]],
    constant float4x4 &transform [[buffer(1)]])
{
    RectVertexOut v_out;
    float4 pos = float4(rectData[vertexID].pos.xy, 0.0, 1.0);
    v_out.position = transform * pos;
    v_out.color = rectData[vertexID].color;
    return v_out;
}

fragment float4 rectFragFn(RectVertexOut in [[stage_in]])
{
    return in.color;
}

struct LineData
{
    float4 color;
    float2 origin;
    float2 opposite;
    float4 thickness;
};

vertex RectVertexOut lineVtxFn(
    uint vertexID [[vertex_id]],
    constant LineData *lineData [[buffer(0)]],
    constant float4x4 &transform [[buffer(1)]])
{
    RectVertexOut v_out;
    uint rem = vertexID % 6;
    uint id = vertexID / 6;
    float2x2 rot = float2x2(0.0, 1.0, -1.0, 0.0);
    float2 offset = lineData[id].opposite - lineData[id].origin;
    offset = (lineData[id].thickness.x / length(offset)) * rot * offset;

    float2 position;
    v_out.color = lineData[id].color;
    if (rem == 0) {
        position = lineData[id].origin - offset;
    } else if (rem == 1) {
        position = lineData[id].origin + offset;
    } else if (rem == 2) {
        position = lineData[id].opposite + offset;
    } else if (rem == 3) {
        position = lineData[id].origin - offset;
    } else if (rem == 4) {
        position = lineData[id].opposite - offset;
    } else if (rem == 5) {
        position = lineData[id].opposite + offset;
    }
    
    v_out.position = transform * float4(position, 0.0, 1.0);
    return v_out;
}
