//
//  Metadata.swift
//  iViewer
//
//  Created by davis.cho on 2018/1/9.
//  Copyright © 2018年 Vivotek. All rights reserved.
//

import UIKit

@objcMembers
open class Frame: NSObject, Codable {
    public var objects: [Object]?
    
    private enum CodingKeys: String, CodingKey {
        case objects = "Objects"
    }
}

@objcMembers
open class Object: NSObject, Codable {
    public var centroid = Centroid()
    public var origin = Origin()
    public var height: Int = 0
    public var gid: Int = 0
    public var originUtcTime: String = ""
    
    private enum CodingKeys: String, CodingKey {
        case centroid = "Centroid"
        case origin = "Origin"
        case height = "Height"
        case gid = "GId"
        case originUtcTime = "OriginUtcTime"
    }
}

@objcMembers
open class Centroid: NSObject, Codable {
    public var x: Int = 0
    public var y: Int = 0
}

@objcMembers
open class Origin: NSObject, Codable {
    public var x: Int = 0
    public var y: Int = 0
}

@objcMembers
open class Metadata: NSObject, Codable {
    public var frame: Frame?
    
    private enum CodingKeys: String, CodingKey {
        case frame = "Frame"
    }
    
    init?(json: String) {
        let decoder = JSONDecoder()
        if let metadata = try? decoder.decode(Metadata.self, from: json.data(using: .utf8)!) {
            self.frame = metadata.frame
        }
        else {
            print("JSON decode error")
            return nil
        }
    }
}
