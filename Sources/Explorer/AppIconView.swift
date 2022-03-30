//
//  File.swift
//  
//
//  Created by YuAo on 2022/3/18.
//

import Foundation
import AppKit

public class LinearGradientView: NSView {
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setup()
    }
    
    
    public var colors: [NSColor] = [] {
        didSet {
            self.needsLayout = true
        }
    }
    
    public var locations: [CGFloat] = [] {
        didSet {
            self.needsLayout = true
        }
    }
    
    public var startPoint: CGPoint = .zero {
        didSet {
            self.needsLayout = true
        }
    }
    
    public var endPoint: CGPoint = CGPoint(x: 1, y: 1) {
        didSet {
            self.needsLayout = true
        }
    }
    
    private func setup() {
        //layer hosting view
        layer = CAGradientLayer()
        wantsLayer = true
    }
    
    private var gradientLayer: CAGradientLayer {
        return self.layer as! CAGradientLayer
    }
    
    public override func layout() {
        super.layout()
        self.gradientLayer.colors = self.colors.compactMap({ $0.cgColor })
        self.gradientLayer.locations = self.locations.count > 0 ? self.locations.map({ NSNumber(value: Float($0)) }) : nil
        self.gradientLayer.startPoint = self.startPoint
        self.gradientLayer.endPoint = self.endPoint
    }
}

@available(macOS 11.0, *)
class AppIconView: NSView {
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private weak var gradientView: LinearGradientView!
    private weak var imageView: NSImageView!
    
    private func setup() {
        let gradientView = LinearGradientView()
        gradientView.colors = [NSColor.darkGray, NSColor.black]
        gradientView.locations = [0, 1]
        gradientView.startPoint = CGPoint(x: 0.5, y: 0)
        gradientView.endPoint = CGPoint(x: 0.5, y: 1)
        self.addSubview(gradientView)
        self.gradientView = gradientView
        
        let imageView = NSImageView(image: NSImage(systemSymbolName: "square.stack.3d.forward.dottedline.fill", accessibilityDescription: nil)!)
        imageView.contentTintColor = .white
        imageView.rotate(byDegrees: 90)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        self.addSubview(imageView)
        self.imageView = imageView
    }
    
    override func layout() {
        super.layout()
        self.imageView.frame = self.bounds.insetBy(dx: self.bounds.width/6, dy: self.bounds.height/6)
        self.gradientView.frame = self.bounds.insetBy(dx: self.bounds.width/11, dy: self.bounds.height/11)
        self.gradientView.layer?.cornerCurve = .continuous
        self.gradientView.layer?.cornerRadius = self.bounds.height/5
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = self.bounds.width/40
        self.gradientView.shadow = shadow
    }
}
