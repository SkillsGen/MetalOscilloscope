//
//  MatrixHelpers.swift
//  MetalTest
//
//  Created by Sebastian Reinolds on 09/06/2018.
//  Copyright © 2018 Sebastian Reinolds. All rights reserved.
//

import MetalKit
import simd


func identityMatrix() -> float4x4 {
    var x: float4x4 = float4x4()
    x.columns.0 = [1, 0, 0, 0]
    x.columns.1 = [0, 1, 0, 0]
    x.columns.2 = [0, 0, 1, 0]
    x.columns.3 = [0, 0, 0, 1]
    
    return x
}

func translationMatrix(position: float3) -> float4x4 {
    var Result = identityMatrix()
    
    Result.columns.3.x = position.x
    Result.columns.3.y = position.y
    Result.columns.3.z = position.z
    
    return Result
}

func scalingMatrix(scale: Float) -> float4x4 {
    var Result = identityMatrix()
    
    Result.columns.0.x = scale
    Result.columns.1.y = scale
    Result.columns.2.z = scale
    Result.columns.3.w = 1
    
    return Result
}

func rotationMatrix(rotVector: float3) -> float4x4 {
    var Result = identityMatrix()
    
    Result.columns.0.x = cos(rotVector.y) * cos(rotVector.z)
    Result.columns.0.y = cos(rotVector.z) * sin(rotVector.x) * sin(rotVector.y) - cos(rotVector.x) * sin(rotVector.z)
    Result.columns.0.z = cos(rotVector.x) * cos(rotVector.z) * sin(rotVector.y) + sin(rotVector.x) * sin(rotVector.z)
    Result.columns.1.x = cos(rotVector.y) * sin(rotVector.z)
    Result.columns.1.y = cos(rotVector.x) * cos(rotVector.z) + sin(rotVector.x) * sin(rotVector.y) * sin(rotVector.z)
    Result.columns.1.z = -cos(rotVector.z) * sin(rotVector.x) + cos(rotVector.x) * sin(rotVector.y) * sin(rotVector.z)
    Result.columns.2.x = -sin(rotVector.y)
    Result.columns.2.y = cos(rotVector.y) * sin(rotVector.x)
    Result.columns.2.z = cos(rotVector.x) * cos(rotVector.y)
    Result.columns.3.w = 1
    
    return Result
}

func projectionMatrix(near: Float, far: Float, aspect: Float, fovy: Float) -> float4x4 {
    let scaleY = 1 / tan(fovy * 0.5)
    let scaleX = scaleY / aspect
    let scaleZ = -(far + near) / (far - near)
    let scaleW = -2 * far * near / (far - near)
    let X = vector_float4(scaleX, 0, 0, 0)
    let Y = vector_float4(0, scaleY, 0, 0)
    let Z = vector_float4(0, 0, scaleZ, -1)
    let W = vector_float4(0, 0, scaleW, 0)
    return float4x4(columns:(X, Y, Z, W))
}
