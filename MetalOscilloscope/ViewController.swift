//
//  ViewController.swift
//  MetalTest
//
//  Created by Sebastian Reinolds on 05/06/2018.
//  Copyright © 2018 Sebastian Reinolds. All rights reserved.
//

import UIKit
import MetalKit
import MetalPerformanceShaders
import simd

class ViewController: UIViewController {
    var device: MTLDevice!
    var metalLayer: CAMetalLayer!
    var computePipeline: MTLComputePipelineState!
    var pipelineState: MTLRenderPipelineState!
    var vertexBuffer: MTLBuffer!
    var commandQueue: MTLCommandQueue!
    var timer: CADisplayLink!
    

    var uniformBuffer: MTLBuffer!
    var zAngle: Float = 0
    
    var vertexData: [Float] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        device = MTLCreateSystemDefaultDevice()
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.frame = view.layer.frame
        view.layer.addSublayer(metalLayer)
        
        
        vertexData = genLines()
        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])
        
        
        let scaling = scalingMatrix(scale: 1.0)
        let transsize = MemoryLayout<Float>.size * 16
        let rotation = rotationMatrix(rotVector: float3(0, 0, 0.0)) * scaling
        var translation = translationMatrix(position: float3(0.0, 0.0, 0.0)) * rotation
        var projMatrix = projectionMatrix(near: 0.1, far: 100, aspect: Float(self.view.bounds.size.width / self.view.bounds.size.height), fovy: 1.484)
        uniformBuffer = device.makeBuffer(length: transsize * 2, options: [])
        memcpy(uniformBuffer.contents(), &translation, transsize)
        memcpy(uniformBuffer.contents() + transsize, &projMatrix, transsize)
        
        
        let defaultLibrary = device.makeDefaultLibrary()!
        let fragmentProgram = defaultLibrary.makeFunction(name: "basic_fragment")
        let vertexProgram = defaultLibrary.makeFunction(name: "basic_vertex")
        let computeProgram = defaultLibrary.makeFunction(name: "compute_shader")
        computePipeline = try! device.makeComputePipelineState(function: computeProgram!)
        
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineStateDescriptor.colorAttachments[1].pixelFormat = .bgra8Unorm // Trace texture
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        commandQueue = device.makeCommandQueue()
        
        
        timer = CADisplayLink(target: self, selector: #selector(ViewController.loop))
        timer.add(to: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
    }

    
    func render() {
        let drawable = metalLayer!.nextDrawable()!
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        
        // Trace texture/buffer/whatever
        let traceDesc: MTLTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: drawable.texture.pixelFormat,
                                                                                       width: drawable.texture.width,
                                                                                       height: drawable.texture.height, mipmapped: false)
        traceDesc.usage = [.shaderRead, .shaderWrite, .renderTarget]
        var traceTexture: MTLTexture = device.makeTexture(descriptor: traceDesc)!
        renderPassDescriptor.colorAttachments[1].texture = traceTexture
        renderPassDescriptor.colorAttachments[1].loadAction = .clear
        renderPassDescriptor.colorAttachments[1].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
    
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        let vertexCount = vertexData.count / 8
        renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: vertexCount, instanceCount: 1)
        renderEncoder.endEncoding()
        
        // Blur trace
        let gaussKernel = MPSImageGaussianBlur(device: device, sigma: 6.0)
        gaussKernel.encode(commandBuffer: commandBuffer, inPlaceTexture: &traceTexture, fallbackCopyAllocator: nil)
        
        
        // Add blurred texture back
        let compute = commandBuffer.makeComputeCommandEncoder()!
        compute.setComputePipelineState(computePipeline)
        compute.setTexture(drawable.texture, index: 0)
        compute.setTexture(traceTexture, index: 1)
        compute.setTexture(drawable.texture, index: 2)
        
        let groupSize = MTLSize(width: 64, height: 64, depth: 1)
        let groups = MTLSize(width: Int(view.bounds.size.width) / groupSize.width+1, height: Int(view.bounds.size.height) / groupSize.height+1, depth: 1)
        compute.dispatchThreadgroups(groupSize, threadsPerThreadgroup: groups)
        compute.endEncoding()

        //Finish
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    
    @objc func loop() {
        autoreleasepool {
            //vertexData[1] -= 0.001
            //memcpy(vertexBuffer.contents(), vertexData, vertexData.count * MemoryLayout.size(ofValue: vertexData[0]))

            zAngle += 0.01
            let scaling = scalingMatrix(scale: 0.9)
            let rotation = rotationMatrix(rotVector: float3(0.0, 0.0, 0.0)) * scaling
            var translation = translationMatrix(position: float3(0.0, 0.0, 0.0)) * rotation
            
            let transsize = MemoryLayout<Float>.size * 16
            memcpy(uniformBuffer.contents(), &translation, transsize)
            
            self.render()
        }
    }
    
    func genLines() -> [Float] {
        var Lines: [Float] = []
        let Width: Float = 2
        let Height: Float = 2
        
        // Generate Grid
        for i in 0...10 {
            for j in 0...9 {
                Lines.append(Width/10 * Float(i) - Width/2)
                Lines.append(Height/10 * Float(j) - Height/2)
                Lines.append(0)
                Lines.append(1)
                
                Lines.append(0.3)
                Lines.append(0.3)
                Lines.append(0.3)
                Lines.append(1)
                
                Lines.append(Width/10 * Float(i) - Width/2)
                Lines.append(Height/10 * Float(j + 1) - Height/2)
                Lines.append(0)
                Lines.append(1)
            
                Lines.append(0.3)
                Lines.append(0.3)
                Lines.append(0.3)
                Lines.append(1)
                
                Lines.append(Width/10 * Float(j) - Width/2)
                Lines.append(Height/10 * Float(i) - Height/2)
                Lines.append(0)
                Lines.append(1)
                
                Lines.append(0.3)
                Lines.append(0.3)
                Lines.append(0.3)
                Lines.append(1)
                
                Lines.append(Width/10 * Float(j + 1) - Width/2)
                Lines.append(Height/10 * Float(i) - Height/2)
                Lines.append(0)
                Lines.append(1)
                
                Lines.append(0.3)
                Lines.append(0.3)
                Lines.append(0.3)
                Lines.append(1)
            }
        }
        
        // Generate Trace (sine wave for testing)
        for i in 0...99 {
            Lines.append((Width/100 * Float(i)) - Width/2)
            Lines.append(sin(Float(i) * Float.pi/50))
            Lines.append(0)
            Lines.append(1)
            
            Lines.append(0)
            Lines.append(1)
            Lines.append(0)
            Lines.append(1)
            
            Lines.append((Width/100 * Float(i+1)) - Height/2)
            Lines.append(sin(Float(i+1) * Float.pi/50))
            Lines.append(0)
            Lines.append(1)

            Lines.append(0)
            Lines.append(1)
            Lines.append(0)
            Lines.append(1)
        }
        return Lines
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

