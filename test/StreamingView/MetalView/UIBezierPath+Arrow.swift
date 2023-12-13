//
//  UIBezierPath+Arrow.swift
//  iViewer
//
//  Created by davis.cho on 2018/2/27.
//  Copyright © 2018年 Vivotek. All rights reserved.
//  https://gist.github.com/mayoff/4146780#file-arrow-swift-L11

import UIKit

@objc extension UIBezierPath {
    
    public class func arrow(from start: CGPoint, to end: CGPoint, tailWidth: CGFloat, headWidth: CGFloat, headLength: CGFloat) -> Self {
        let length = hypot(end.x - start.x, end.y - start.y)
        let tailLength = length - headLength
        
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { return CGPoint(x: x, y: y) }
        let points: [CGPoint] = [
            p(0.0, tailWidth / 2.0),
            p(tailLength, tailWidth / 2.0),
            p(tailLength, headWidth / 2.0),
            p(length, 0.0),
            p(tailLength, -headWidth / 2.0),
            p(tailLength, -tailWidth / 2.0),
            p(0.0, -tailWidth / 2.0)
        ]
        
        let cosine = (end.x - start.x) / length
        let sine = (end.y - start.y) / length
        let transform = CGAffineTransform(a: cosine, b: sine, c: -sine, d: cosine, tx: start.x, ty: start.y)
        
        let path = CGMutablePath()
        path.addLines(between: points, transform: transform)
        path.closeSubpath()
        
        return self.init(cgPath: path)
    }
    
}
