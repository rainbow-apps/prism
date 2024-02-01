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
    constant PointData *pointData[[buffer(0)]],
    constant float2 &frameSize [[buffer(1)]])
{
    PointVertexOut v_out;
    v_out.position = float4((4.0 * pointData[vertexID].pos.x - frameSize.x) / frameSize.x, (4.0 * pointData[vertexID].pos.y - frameSize.y) / frameSize.y, 0, 1);
    v_out.color = pointData[vertexID].color;
    v_out.size = pointData[vertexID].size;
    return v_out;
}

fragment float4 pointFragFn(PointVertexOut in [[stage_in]])
{
    return in.color;
}
