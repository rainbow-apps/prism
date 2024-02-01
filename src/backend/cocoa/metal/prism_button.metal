#include <metal_stdlib>
using namespace metal;

struct ShaderData
{
    float4 bg;
    float4 fg;
    float4 hl_bg;
    float4 hl_fg;
    uint32_t frame_nr;
    float text_width;
    float text_height;
    float horizontal_pad;
    float vertical_pad;
    float border_thickness;
    bool clicked;
    bool present;
};

vertex float4 vertexFn(uint vertexID [[vertex_id]], constant float2 *positions[[buffer (0)]])
{
    float4 out = float4(0.0, 0.0, 0.0, 1.0);
    out.xy = positions[vertexID].xy;
    return out;
}

// https://www.shadertoy.com/view/4llXD7
float sdRoundBox(float2 point, float2 bounds, float roundness ) 
{
    float2 q = abs(point) - bounds + roundness;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - roundness;
}

float4 clicked(float dist, float text_alpha, constant ShaderData &shaderData)
{
    float4 out = mix(shaderData.hl_fg, shaderData.hl_bg, text_alpha);
    out = mix(out, float4(0.0), smoothstep(0.0, 1.5, dist));
    return out;
}

float4 present(float dist, float text_alpha, constant ShaderData &shaderData)
{
    float4 out = mix(shaderData.hl_bg, shaderData.hl_fg, text_alpha);
    out = mix(out, shaderData.hl_fg, smoothstep(-shaderData.border_thickness, -shaderData.border_thickness + 1.5, dist));
    out = mix(out, float4(0.0), smoothstep(0.0, 1.5, dist));
    return out;
}

float4 ordinary(float dist, float text_alpha, constant ShaderData &shaderData)
{
    float4 out = mix(shaderData.bg, shaderData.fg, text_alpha);
    out = mix(out, shaderData.fg, smoothstep(-shaderData.border_thickness, -shaderData.border_thickness + 1.5, dist));
    out = mix(out, float4(0.0), smoothstep(0.0, 1.5, dist));
    return out;
}

fragment float4 fragmentFn(float4 in [[position]],
    texture2d<float, access::read> txt [[texture(0)]],
    constant ShaderData &shaderData [[buffer(0)]])
{
    float tx = in.x - 0.5 * (shaderData.horizontal_pad + shaderData.border_thickness);
    float ty = in.y - 0.5 * (shaderData.vertical_pad +  shaderData.border_thickness);
    tx = (tx < 0) ? shaderData.text_width : (tx > shaderData.text_width) ? shaderData.text_width : tx;
    ty = (ty < 0) ? shaderData.text_height : (ty > shaderData.text_height) ? shaderData.text_height : ty;
    ushort2 texcoord = ushort2((ushort)tx, (ushort)ty);
    float4 overlay = txt.read(texcoord);
    float2 center = 0.5 * float2(shaderData.text_width + shaderData.horizontal_pad + shaderData.border_thickness, shaderData.text_height + shaderData.vertical_pad + shaderData.border_thickness);
    float dist = sdRoundBox(in.xy - center, 0.99 * center, 20.0);
    if (shaderData.clicked) {
        if (shaderData.frame_nr < 10)
        {
            return mix(present(dist, overlay.a, shaderData), clicked(dist, overlay.a, shaderData), shaderData.frame_nr / 10.0);
        }
        return clicked(dist, overlay.a, shaderData);
    }
    if (shaderData.present) {
        if (shaderData.frame_nr < 10)
        {
            return mix(ordinary(dist, overlay.a, shaderData), present(dist, overlay.a, shaderData), shaderData.frame_nr / 10.0);
        }
        return present(dist, overlay.a, shaderData);
    }
    return ordinary(dist, overlay.a, shaderData);
}


