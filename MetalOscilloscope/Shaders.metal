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
    float4x4 matrix = uniforms.modelMatrix;
    //float4x4 projectionMatrix = uniforms.projectionMatrix;
    
    Vertex in = vertices[vid];
    Vertex out;

    out.position = matrix * float4(in.position);
    
    // Barrel Distortion
    float barrelDistortion = 0.95f;
    if(!(out.position.x == 0.0f && out.position.y == 0.0f))
    {
        float2 newCoords = float2(out.position.x, out.position.y);
        
        float theta = atan2(newCoords.y, newCoords.x);
        float radius = length(newCoords);
        
        radius = pow(radius, barrelDistortion);
        float2 outCoords = float2(radius * cos(theta), radius * sin(theta));
        
        out.position.x = outCoords.x;
        out.position.y = outCoords.y;
    }
    
    out.color = in.color;
    return out;
}

fragment frag_out basic_fragment(Vertex in [[ stage_in ]])
{
    frag_out fragOut;
    
    fragOut.color0 = float4(0.0, 0.0, 0.0, 1.0);
    fragOut.color1 = float4(0.0, 0.0, 0.0, 1.0);
    
    if(in.color[1] == 1.0) // Seperate green trace
    {
        fragOut.color1 = in.color; // Trace
    }
    fragOut.color0 = in.color; // Grid
    
    return fragOut;
}


// Add back the blurred trace
kernel void compute_shader(texture2d<float, access::read> grid    [[ texture(0) ]],
                           texture2d<float, access::read> trace   [[ texture(1) ]],
                           texture2d<float, access::write> dest   [[ texture(2) ]],
                           uint2 gid                              [[ thread_position_in_grid ]])
{
    float4 gridColor = grid.read(gid);
    float4 traceColor = trace.read(gid) * 5;          //Make blurred trace brighter
    float4 resultColor = gridColor + traceColor;
    
    dest.write(resultColor, gid);
}

