//
//  Point3D.swift
//  iViewer
//
//  Created by davis.cho on 2018/1/4.
//  Copyright © 2018年 Vivotek. All rights reserved.
//b

import Foundation

@objcMembers
open class Point3D: NSObject, NSCopying {
    public var x: Double = 0.0
    public var y: Double = 0.0
    public var z: Double = 0.0
    
    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    static func == (lhs: Point3D, rhs: Point3D) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = Point3D(x: x, y: y, z: z)
        return copy
    }
}
