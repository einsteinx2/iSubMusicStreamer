//
//  EqualizerView.swift
//  iSub
//
//  Created by Ben Baron on 2/25/24.
//  Copyright © 2024 Ben Baron. All rights reserved.
//

import UIKit
import QuartzCore
import OpenGLES
import Resolver
import CocoaLumberjackSwift

@objc enum VisualizerType: Int {
    case none      = 0
    case line      = 1
    case skinnyBar = 2
    case fatBar    = 3
    case aphexFace = 4
    case maxValue  = 5
}

struct RGBQUAD2 {
    var rgbRed: UInt8
    var rgbGreen: UInt8
    var rgbBlue: UInt8
    var alpha: UInt8
}

private let drawInterval: TimeInterval = 1.0 / 20.0
private let specWidth: Int = 512 // 256 or 512
private let specHeight: Int = 512 // 256 or 512
private let specbufLength: Int = specWidth * specHeight
private let palleteLength: Int = specHeight + 128

final class EqualizerView: UIView {
    
    @Injected private var settings: SavedSettings
    @Injected private var player: BassPlayer
    
//    var location: CGPoint
//    var previousLocation: CGPoint
    var drawTimer: Timer?
    var visualizerType: VisualizerType = .none
    
    // The pixel dimensions of the backbuffer
    private var backingWidth: GLint = 0
    private var backingHeight: GLint = 0
    
    private var context: EAGLContext!
    
    // OpenGL names for the renderbuffer and framebuffers used to render to this view
    private var viewRenderbuffer: GLuint = 0
    private var viewFramebuffer: GLuint = 0
    
    // OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist)
    private var depthRenderbuffer: GLuint = 0
    
    private var imageTexture: GLuint = 0
    private var needsErase: Bool = false

    private var specdc: CGContext!

    private var specbuf: UnsafeMutableRawPointer = calloc(specbufLength, MemoryLayout<UInt32>.size)
    private var palette: UnsafeMutableRawPointer = calloc(palleteLength, MemoryLayout<UInt32>.size)
    private var specpos: Int = 0
    
    private func setupDrawEQPalette() {
        let scale: Int = 2
        
        let pal = palette.bindMemory(to: RGBQUAD2.self, capacity: palleteLength)
        
        for a in 1..<128*scale {
            pal[a].rgbBlue  = UInt8(256 - ((2 / scale) * a))
            pal[a].rgbGreen = UInt8((2 / scale) * a)
        }
        
        for a in 1..<128*scale {
            let start = 128 * scale - 1;
            pal[start+a].rgbGreen = UInt8(256 - ((2 / scale) * a))
            pal[start+a].rgbRed   = UInt8((2 / scale) * a)
        }
        
        for a in 0..<32 {
            pal[specHeight + a].rgbBlue       = UInt8(8 * a);
            pal[specHeight + 32 + a].rgbBlue  = 255;
            pal[specHeight + 32 + a].rgbRed   = UInt8(8 * a);
            pal[specHeight + 64 + a].rgbRed   = 255;
            pal[specHeight + 64 + a].rgbBlue  = UInt8(8 * (31 - a));
            pal[specHeight + 64 + a].rgbGreen = UInt8(8 * a);
            pal[specHeight + 96 + a].rgbRed   = 255;
            pal[specHeight + 96 + a].rgbGreen = 255;
            pal[specHeight + 96 + a].rgbBlue  = UInt8(8 * a);
        }
    }
    
    private func setupDrawBitmap() {
        specdc = CGContext(data: specbuf,
                           width: specWidth,
                           height: specHeight,
                           bitsPerComponent: 8,
                           bytesPerRow: specWidth * 4,
                           space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    }
    
    // Implement this to override the default layer class (which is [CALayer class]).
    // We do this so that our view will be backed by a layer that is capable of OpenGL ES rendering.
    override class var layerClass: AnyClass {
        CAEAGLLayer.self
    }
    
    private func setup() {
        setupDrawEQPalette()
        setupDrawBitmap()
        
        isUserInteractionEnabled = true
        
        if let eaglLayer = layer as? CAEAGLLayer {
            eaglLayer.isOpaque = true
            // In this application, we want to retain the EAGLDrawable contents after a call to presentRenderbuffer.
            eaglLayer.drawableProperties = [kEAGLDrawablePropertyRetainedBacking: true, kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8]
        }
        
        context = EAGLContext(api: .openGLES1)
        
        if context == nil || !EAGLContext.setCurrent(context) {
            return
        }
        
        // Use OpenGL ES to generate a name for the texture.
        glGenTextures(1, &imageTexture)
        // Bind the texture name.
        glBindTexture(GLenum(GL_TEXTURE_2D), imageTexture)
        // Set the texture parameters to use a minifying filter and a linear filer (weighted average)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
        
        //Set up OpenGL states
        glMatrixMode(GLenum(GL_PROJECTION))
        glOrthof(0, GLfloat(bounds.size.width), 0, GLfloat(bounds.size.height), -1, 1)
        glViewport(0, 0, GLsizei(bounds.size.width), GLsizei(bounds.size.height))
        glMatrixMode(GLenum(GL_MODELVIEW))
        
        glDisable(GLenum(GL_DITHER))
        glEnable(GLenum(GL_TEXTURE_2D))
        glEnableClientState(GLenum(GL_VERTEX_ARRAY))
        glEnable(GLenum(GL_POINT_SPRITE_OES))
        glTexEnvf(GLenum(GL_POINT_SPRITE_OES), GLenum(GL_COORD_REPLACE_OES), GLfloat(GL_TRUE))
        
        // TODO: Remove force unwrapping
        changeType(VisualizerType(rawValue: Int(settings.currentVisualizerType.rawValue))!)
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(stopEqDisplay), name: UIApplication.willResignActiveNotification)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(startEqDisplay), name: UIApplication.didBecomeActiveNotification)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
        
        free(palette)
        free(specbuf)
        
        drawTimer?.invalidate()
        
        if imageTexture != 0 {
            glDeleteTextures(1, &imageTexture)
        }
        
        if EAGLContext.current() == context {
            EAGLContext.setCurrent(nil)
        }
    }
    
    @objc func startEqDisplay() {
        guard drawTimer == nil else { return }
        
        drawTimer = Timer.scheduledTimer(timeInterval: drawInterval, target: self, selector: #selector(drawTheEq), userInfo: nil, repeats: true)
    }
    
    @objc func stopEqDisplay() {
        drawTimer?.invalidate()
        drawTimer = nil
    }
    
    @objc func drawTheEq() {
        guard player.isPlaying && visualizerType != .none else { return }
        
        player.visualizer.readAudioData()
        
//        var x = 0
        var y = 0
        var y1 = 0
        let spec = specbuf.bindMemory(to: RGBQUAD2.self, capacity: specbufLength)
        let pal = palette.bindMemory(to: RGBQUAD2.self, capacity: palleteLength)
        
        switch(visualizerType) {
        case .line:
            eraseBitBuffer()
            for x in 0..<specWidth {
                let v = (32767 - Int(player.visualizer.lineSpecData(index: x))) * specHeight / 65536
                if x == 0 {
                    y = v
                }
                
                repeat {
                    // draw line from previous sample...
                    if y < v {
                        y += 1
                    } else if y > v {
                        y -= 1
                    }
                    
                    let specbufIndex = y * specWidth + x
                    let palleteIndex = abs(y - specHeight / 2) * 2 + 1
                    if specbufIndex > 0 && specbufIndex < specbufLength && palleteIndex >= 0 && palleteIndex < palleteLength {
                        spec[specbufIndex] = pal[palleteIndex];
                    }
                } while y != v
            }
        case .skinnyBar:
            eraseBitBuffer()
            for x in 0..<specWidth/2 {
                y = Int(sqrt(player.visualizer.fftData(index: x + 1)) * 3 * Float(specHeight) - 4) // scale it (sqrt to make low values more visible)
                //y = Int(player.visualizer.fftData(index: x + 1) * 10 * Float(specHeight)) // scale it (linearly)
                if y > specHeight {
                    y = specHeight // cap it
                }
                
                if x > 0 {
                    y1 = (y + y1) / 2 // interpolate from previous to make the display smoother
                    y1 -= 1
                    while y1 >= 0 {
                        let specbufIndex = (specHeight - 1 - y1) * specWidth + x * 2 - 1
                        let palleteIndex = y1 + 1
                        if specbufIndex > 0 && specbufIndex < specbufLength && palleteIndex >= 0 && palleteIndex < palleteLength {
                            spec[specbufIndex] = pal[palleteIndex]
                        }
                        y1 -= 1
                    }
                }
    
                y1 = y
                y -= 1
                while y >= 0 {
                    let specbufIndex = (specHeight - 1 - y) * specWidth + x * 2
                    let palleteIndex = y + 1
                    if specbufIndex > 0 && specbufIndex < specbufLength && palleteIndex >= 0 && palleteIndex < palleteLength {
                        spec[specbufIndex] = pal[palleteIndex] // draw level
                    }
                    y -= 1
                }
            }
        case .fatBar:
            var b0 = 0
            eraseBitBuffer()
            let bands = 28
            for x in 0..<bands {
                var peak: Float = 0
                var b1: Int = Int(pow(2, (Double(x) * 10.0) / Double(bands - 1)))
                if b1 > 1023 {
                    b1 = 1023
                }
                if b1 <= b0 {
                    b1 = b0 + 1 // make sure it uses at least 1 FFT bin
                }
                
                while b0 < b1 {
                    if peak < player.visualizer.fftData(index: 1 + b0) {
                        peak = player.visualizer.fftData(index: 1 + b0)
                    }
                    b0 += 1
                }
                
                y = Int(sqrt(peak) * 3 * Float(specHeight) - 4) // scale it (sqrt to make low values more visible)
                
                if y > specHeight {
                    y = specHeight // cap it
                }
                
                y -= 1
                while y >= 0 {
                    for y1 in 0..<specWidth/bands-2 {
                        let specbufIndex = (specHeight - 1 - y) * specWidth + x * (specWidth / bands) + y1
                        let palleteIndex = y + 1
                        if specbufIndex > 0 && specbufIndex < specbufLength && palleteIndex >= 0 && palleteIndex < palleteLength {
                            spec[specbufIndex] = pal[y + 1] // draw bar
                        }
                    }
                    y -= 1
                }
            }
        case .aphexFace:
            for x in 0..<specHeight {
                y = Int(sqrt(player.visualizer.fftData(index: x + 1)) * 3 * 127) // scale it (sqrt to make low values more visible)
                if y > 127 {
                    y = 127 // cap it
                }
                let specbufIndex = (specHeight - 1 - x) * specWidth + specpos
                let paletteIndex = specHeight - 1 + y
                if specbufIndex > 0 && specbufIndex < specbufLength && paletteIndex >= 0 && paletteIndex < palleteLength {
                    spec[specbufIndex] = pal[paletteIndex] // plot it
                }
            }
            
            // move marker onto next position
            specpos = (specpos + 1) % specWidth
            for x in 0..<specHeight {
                var specbufIndex = x * specWidth + specpos
                var paletteIndex = specHeight + 126
                if specbufIndex > 0 && specbufIndex < specbufLength && paletteIndex >= 0 && paletteIndex < palleteLength {
                    spec[specbufIndex] = pal[paletteIndex];
                }
                
                if specpos + 1 < specWidth {
                    specbufIndex = x * specWidth + specpos + 1
                    paletteIndex = specHeight + 126
                    if specbufIndex > 0 && specbufIndex < specbufLength && paletteIndex >= 0 && paletteIndex < palleteLength {
                        spec[specbufIndex] = pal[paletteIndex]
                    }
                }
            }
        default:
            break
        }
        
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, GL_RGBA, GLsizei(specWidth), GLsizei(specHeight), 0, GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), specbuf)
        
        EAGLContext.setCurrent(context)
        glBindFramebufferOES(GLenum(GL_FRAMEBUFFER_OES), viewFramebuffer)
        
        let width = GLfloat(frame.width)
        let height = GLfloat(frame.height)
        let box: [GLfloat] = [ 0,     height, 0,
                               width, height, 0,
                               width,      0, 0,
                               0,          0, 0]
        
        let tex: [GLfloat] = [0,0,
                              1,0,
                              1,1,
                              0,1]
        
        glEnableClientState(GLenum(GL_VERTEX_ARRAY));
        glEnableClientState(GLenum(GL_TEXTURE_COORD_ARRAY));
        
        glVertexPointer(3, GLenum(GL_FLOAT), 0, box);
        glTexCoordPointer(2, GLenum(GL_FLOAT), 0, tex);
        
        glDrawArrays(GLenum(GL_TRIANGLE_FAN), 0, 4);
        
        glDisableClientState(GLenum(GL_VERTEX_ARRAY));
        glDisableClientState(GLenum(GL_TEXTURE_COORD_ARRAY));
        
        //Display the buffer
        glBindRenderbufferOES(GLenum(GL_RENDERBUFFER_OES), viewRenderbuffer);
        
        if (UIApplication.shared.applicationState == .active) {
            // Make sure we didn't resign active while the method was already running
            context.presentRenderbuffer(Int(GL_RENDERBUFFER_OES))
        }
    }
    
    // If our view is resized, we'll be asked to layout subviews.
    // This is the perfect opportunity to also update the framebuffer so that it is
    // the same size as our display area.
    override func layoutSubviews() {
        EAGLContext.setCurrent(context)
        
        glMatrixMode(GLenum(GL_PROJECTION));
        let scaleFactor = self.contentScaleFactor;
        glLoadIdentity()
        glOrthof(0, GLfloat(bounds.width * scaleFactor), 0, GLfloat(bounds.height * scaleFactor), -1, 1)
        glViewport(0, 0, GLsizei(bounds.width * scaleFactor), GLsizei(bounds.height * scaleFactor))
        glMatrixMode(GLenum(GL_MODELVIEW))
        
        destroyFramebuffer()
        createFramebuffer()
        
        // Clear the framebuffer the first time it is allocated
        if needsErase {
            erase()
            needsErase = false
        }
    }
    
    @discardableResult
    func createFramebuffer() -> Bool {
        // Generate IDs for a framebuffer object and a color renderbuffer
        glGenFramebuffersOES(1, &viewFramebuffer);
        glGenRenderbuffersOES(1, &viewRenderbuffer);
        
        glBindFramebufferOES(GLenum(GL_FRAMEBUFFER_OES), viewFramebuffer);
        glBindRenderbufferOES(GLenum(GL_RENDERBUFFER_OES), viewRenderbuffer);
        // This call associates the storage for the current render buffer with the EAGLDrawable (our CAEAGLLayer)
        // allowing us to draw into a buffer that will later be rendered to screen wherever the layer is (which corresponds with our view).
        context.renderbufferStorage(Int(GL_RENDERBUFFER_OES), from: layer as? EAGLDrawable)
        glFramebufferRenderbufferOES(GLenum(GL_FRAMEBUFFER_OES), GLenum(GL_COLOR_ATTACHMENT0_OES), GLenum(GL_RENDERBUFFER_OES), viewRenderbuffer);
        
        glGetRenderbufferParameterivOES(GLenum(GL_RENDERBUFFER_OES), GLenum(GL_RENDERBUFFER_WIDTH_OES), &backingWidth);
        glGetRenderbufferParameterivOES(GLenum(GL_RENDERBUFFER_OES), GLenum(GL_RENDERBUFFER_HEIGHT_OES), &backingHeight);
        
        // For this sample, we also need a depth buffer, so we'll create and attach one via another renderbuffer.
        glGenRenderbuffersOES(1, &depthRenderbuffer);
        glBindRenderbufferOES(GLenum(GL_RENDERBUFFER_OES), depthRenderbuffer);
        glRenderbufferStorageOES(GLenum(GL_RENDERBUFFER_OES), GLenum(GL_DEPTH_COMPONENT16_OES), backingWidth, backingHeight);
        glFramebufferRenderbufferOES(GLenum(GL_FRAMEBUFFER_OES), GLenum(GL_DEPTH_ATTACHMENT_OES), GLenum(GL_RENDERBUFFER_OES), depthRenderbuffer);
        
        if glCheckFramebufferStatusOES(GLenum(GL_FRAMEBUFFER_OES)) != GL_FRAMEBUFFER_COMPLETE_OES {
            DDLogError("[EqualizerView] failed to make complete framebuffer object \(glCheckFramebufferStatusOES(GLenum(GL_FRAMEBUFFER_OES)))")
            return false
        }
        
        return true
    }
    
    // Clean up any buffers we have allocated.
    func destroyFramebuffer() {
        glDeleteFramebuffersOES(1, &viewFramebuffer);
        viewFramebuffer = 0;
        glDeleteRenderbuffersOES(1, &viewRenderbuffer);
        viewRenderbuffer = 0;
        
        if depthRenderbuffer != 0 {
            glDeleteRenderbuffersOES(1, &depthRenderbuffer);
            depthRenderbuffer = 0;
        }
    }
    
    // Erases the screen
    func erase() {
        EAGLContext.setCurrent(context)
        
        //Clear the buffer
        glBindFramebufferOES(GLenum(GL_FRAMEBUFFER_OES), viewFramebuffer)
        glClearColor(0, 0, 0, 0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        //Display the buffer
        glBindRenderbufferOES(GLenum(GL_RENDERBUFFER_OES), viewRenderbuffer)
        context.presentRenderbuffer(Int(GL_RENDERBUFFER_OES))
    }
    
    func eraseBitBuffer() {
        memset(specbuf, 0, (specWidth * specHeight * MemoryLayout<UInt32>.size))
    }
    
    func changeType(_ type: VisualizerType) {
        switch type {
        case .none:
            player.visualizer.type = .none
            eraseBitBuffer()
            erase()
            stopEqDisplay()
            visualizerType = .none
            
        case .line:
            player.visualizer.type = .line
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST);
            visualizerType = .line;
            startEqDisplay()
            
        case .skinnyBar:
            player.visualizer.type = .fft
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
            visualizerType = .skinnyBar
            startEqDisplay()
        
        case .fatBar:
            player.visualizer.type = .fft
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST);
            visualizerType = .fatBar
            startEqDisplay()
            
        case .aphexFace:
            player.visualizer.type = .fft
            eraseBitBuffer()
            specpos = 0;
            glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
            visualizerType = .aphexFace
            startEqDisplay()
            
        case .maxValue:
            break
        }
        settings.currentVisualizerType = ISMSBassVisualType(rawValue: UInt32(visualizerType.rawValue))
    }
    
    func nextType() {
        var newType = visualizerType.rawValue + 1
        if newType == VisualizerType.maxValue.rawValue {
            newType = 0
        }
        
        changeType(VisualizerType(rawValue: newType)!)
    }
    
    func prevType() {
        var newType = visualizerType.rawValue - 1
        if newType < 0 {
            newType = VisualizerType.maxValue.rawValue - 1
        }
        
        changeType(VisualizerType(rawValue: newType)!)
    }
}
