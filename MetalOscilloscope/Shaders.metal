//
//  Shaders.metal
//  MetalTest
//
//  Created by Sebastian Reinolds on 05/06/2018.
//  Copyright © 2018 Sebastian Reinolds. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


struct Vertex {
    float4 position [[ position ]];
    float4 color;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 projectionMatrix;
};

struct frag_out {
    float4 color0 [[ color(0) ]];
    float4 color1 [[ color(1) ]];
};

vertex Vertex basic_vertex(constant Vertex* vertices   [[ buffer(0) ]],
                           constant Uniforms &uniforms [[ buffer(1) ]],
                           unsigned int vid            [[ vertex_id ]])
{
    float4x4 Matrix = uniforms.modelMatrix;
    //float4x4 projectionMatrix = uniforms.projectionMatrix;
    
    Vertex In = vertices[vid];
    Vertex Out;

    Out.position = Matrix * float4(In.position);
    
    if(!(Out.position.x == 0.0f && Out.position.y == 0.0f))
    {
        float2 newcoords = float2(Out.position.x, Out.position.y);
        
        float theta = atan2(newcoords.y, newcoords.x);
        float radius = length(newcoords);
        
        radius = pow(radius, 0.95f);
        
        float2 outcoords = float2(radius * cos(theta), radius * sin(theta));
        
        Out.position.x = outcoords.x;
        Out.position.y = outcoords.y;
    }
    
    Out.color = In.color;
    return Out;
}

fragment frag_out basic_fragment(Vertex In [[ stage_in ]])
{
    frag_out FragOut;
    
    FragOut.color0 = float4(0.0, 0.0, 0.0, 1.0);
    FragOut.color1 = float4(0.0, 0.0, 0.0, 1.0);
    
    
    if(In.color[1] == 1.0)
    {
        FragOut.color1 = In.color; // Trace
    }
    FragOut.color0 = In.color; // Grid
    
    return FragOut;
}

kernel void compute_shader(texture2d<float, access::read> grid    [[ texture(0) ]],
                           texture2d<float, access::read> trace   [[ texture(1) ]],
                           texture2d<float, access::write> dest   [[ texture(2) ]],
                           uint2 gid                              [[ thread_position_in_grid ]])
{
    float4 gridColor = grid.read(gid);
    float4 traceColor = trace.read(gid) * 5;
    float4 resultColor = gridColor + traceColor;
    
    dest.write(resultColor, gid);
}

