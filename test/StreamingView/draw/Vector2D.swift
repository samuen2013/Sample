//
//  Vector2D.swift
//  iViewer
//
//  Created by davis.cho on 2018/3/2.
//  Copyright © 2018年 Vivotek. All rights reserved.
//

import UIKit

@objcMembers
public class Vector2D: NSObject, NSCopying {
    public var x: Double = 0.0
    public var y: Double = 0.0
    
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    
    public static func == (lhs: Vector2D, rhs: Vector2D) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = Vector2D(x: x, y: y)
        return copy
    }
    
    public func dotProduct(_ other: Vector2D) -> Double {
        return x * other.x + y * other.y
    }
    
    public func times(_ factor: Double) -> Vector2D {
        return Vector2D(x: x * factor, y: y * factor)
    }
    
    public func plus(_ other: Vector2D) -> Vector2D {
        return Vector2D(x: x + other.x, y: y + other.y)
    }
    
    public func minus(_ other: Vector2D) -> Vector2D {
        return Vector2D(x: x - other.x, y: y - other.y)
    }
    
    public func normalized() -> Vector2D {
        return Vector2D(x: x / length(), y: y / length())
    }
    
    public func length() -> Double {
        return sqrt(x * x + y * y)
    }
    
    public func rotate(_ theta: Double) -> Vector2D {
        return Vector2D(x: x * cos(theta) - y * sin(theta), y: x * sin(theta) + y * cos(theta))
    }
    
    public func translate(_ other: Vector2D) -> Vector2D {
        return Vector2D(x: x + other.x, y: y + other.y)
    }
    
}
