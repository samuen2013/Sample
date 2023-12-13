//
//  ProjectModel.swift
//  iViewer
//
//  Created by davis.cho on 2018/1/4.
//  Copyright © 2018年 Vivotek. All rights reserved.
//

import UIKit

@objcMembers
open class ProjectModel: NSObject {
    public var cx: Double = 0.0
    public var cy: Double = 0.0
    public var fx: Double = 0.0
    public var fy: Double = 0.0
    public var k = [Double](repeating: 0.0, count: 12)
    public var camHeight: Int = 0
    public var angle: Int = 0
    public var orgHeight: Int = 0
    public var orgWidth: Int = 0
    public var isFisheye: Int? = nil
    public var moduleName: String? = nil
    public var a: Double = 0.0
    public var f: Double = 0.0
    public var offsetX: Int = 0
    public var offsetY: Int = 0
    public var roiHeight: Int = 0
    public var roiWidth: Int = 0
    public var resolutionW: Int = 0
    public var resolutionH: Int = 0
    public var modResolutionH: Int = 0
    public var zoomInFactor: Double = 0.0
    public var zoomInOffsetX: Int = 0
    public var zoomInOffsetY: Int = 0
    public var translationX: Int = 0
    public var translationY: Int = 0
    public var oriOToLdcTable: [Double]? = nil
    
    struct ProjectModelJSON: Codable {
        var baseline: Double?
        var camHeight: Int?
        var cx: Double?
        var cy: Double?
        var focalLength: Double?
        var orgHeight: Int?
        var orgWidth: Int?
        var offsetX: Int?
        var offsetY: Int?
        var roiHeight: Int?
        var roiWidth: Int?
        var resolutionH: Int?
        var resolutionW: Int?
        var rollAngle: Int?
        var tiltAngle: Int?
        var zoomInFactor: Double?
        var zoomInOffsetX: Int?
        var zoomInOffsetY: Int?
        var d1: [[Double]]?
        var isFisheye: Int?
        var m1: [[Double]]?
        var moduleName: String?
        
        enum CodingKeys: String, CodingKey {
            case baseline = "Baseline"
            case camHeight = "CamHeight"
            case cx = "Cx"
            case cy = "Cy"
            case focalLength = "FocalLength"
            case orgHeight = "ORGHeight"
            case orgWidth = "ORGWidth"
            case offsetX = "OffsetX"
            case offsetY = "OffsetY"
            case roiHeight = "ROIHeight"
            case roiWidth = "ROIWidth"
            case resolutionH = "ResolutionH"
            case resolutionW = "ResolutionW"
            case rollAngle = "RollAngle"
            case tiltAngle = "TiltAngle"
            case zoomInFactor = "ZoomInFactor"
            case zoomInOffsetX = "ZoomInOffsetX"
            case zoomInOffsetY = "ZoomInOffsetY"
            case d1 = "D1"
            case isFisheye = "IsFishEye"
            case m1 = "M1"
            case moduleName = "ModuleName"
        }
    }
    
    init?(fromJSON jsonString: String) {
        /*
         // 3D
         let json3D = "{\"Baseline\":0.0082366634160280228,\"CamHeight\":3000,\"Cx\":162.20793151855469,\"Cy\":103.68580627441406,\"FocalLength\":112.40855407714844,\"ORGHeight\":960,\"ORGWidth\":1280,\"OffsetX\":0,\"OffsetY\":0,\"ROIHeight\":588,\"ROIWidth\":924,\"ResolutionH\":203,\"ResolutionW\":320,\"RollAngle\":0,\"TiltAngle\":0,\"ZoomInFactor\":1,\"ZoomInOffsetX\":-1,\"ZoomInOffsetY\":-1}"
         
         // 2D Fisheye
         let json2DFisheye = "{\"CamHeight\": 3650, \"D1\": [[0.0028178513829870236], [-0.0043344125647008491], [0.0018986355872795579], [-0.0018514984051288441], [0], [0], [0], [0], [0], [0], [0], [0]], \"IsFishEye\": 1, \"M1\": [[604.91745876366353, 0, 960.83291638524902], [0, 604.82868224884903, 954.24502554060841], [0, 0, 1]], \"ModuleName\": \"FE9381-EHV\", \"ORGHeight\": 1920, \"ORGWidth\": 1920, \"TiltAngle\": 0}"
         
         let json2D = "{\"CamHeight\":3490,\"D1\":[[0.32704227796539372],[-0.03351939024260478],[0],[0],[0.0030272013595855069],[0.79215142629508543],[0],[0],[0],[0],[0],[0]],\"IsFishEye\":0,\"M1\":[[1066.6438479189418,0,971.10284618716609],[0,1065.5069680757222,547.91024442133749],[0,0,1]],\"ModuleName\":\"FD8365-HTV-v2\",\"ORGHeight\":1080,\"ORGWidth\":1920,\"RollAngle\":355,\"TiltAngle\":66}"
         */
        
        let decoder = JSONDecoder()
        if let model = try? decoder.decode(ProjectModelJSON.self, from: jsonString.data(using: .utf8)!) {
            if let m1 = model.m1 {
                cx = m1[0][2]
                cy = m1[1][2]
                fx = m1[0][0]
                fy = m1[1][1]
            }
            else {
                if let cx = model.cx {
                    self.cx = cx
                }
                
                if let cy = model.cy {
                    self.cy = cy
                }
            }
            
            if let d1 = model.d1 {
                for (index, element) in d1.enumerated() {
                    k[index] = element[0]
                }
            }
            
            if let camHeight = model.camHeight {
                self.camHeight = camHeight
            }
            
            if let angle = model.tiltAngle {
                self.angle = angle
            }
            
            if let orgHeight = model.orgHeight {
                self.orgHeight = orgHeight
            }
            
            if let orgWidth = model.orgWidth {
                self.orgWidth = orgWidth
            }
            
            if let isFisheye = model.isFisheye {
                self.isFisheye = isFisheye
            }
            
            if let moduleName = model.moduleName {
                self.moduleName = moduleName
            }
            
            if let a = model.baseline {
                self.a = a
            }
            
            if let f = model.focalLength {
                self.f = f
            }
            
            if let offsetX = model.offsetX {
                self.offsetX = offsetX
            }
            
            if let offsetY = model.offsetY {
                self.offsetY = offsetY
            }
            
            if let roiHeight = model.roiHeight {
                self.roiHeight = roiHeight
            }
            
            if let roiWidth = model.roiWidth {
                self.roiWidth = roiWidth
            }
            
            if let resolutionW = model.resolutionW {
                self.resolutionW = resolutionW
            }
            
            if let resolutionH = model.resolutionH {
                self.resolutionH = resolutionH
            }
            
            if resolutionW != 0 {
                modResolutionH = (Double(resolutionH) / Double(resolutionW) > 0.6125) ? Int(Double(resolutionW) * 0.6125): resolutionH
            }
            
            if let zoomInFactor = model.zoomInFactor {
                self.zoomInFactor = Double(zoomInFactor)
            }
            
            if let zoomInOffsetX = model.zoomInOffsetX {
                self.zoomInOffsetX = zoomInOffsetX
            }
            
            if let zoomInOffsetY = model.zoomInOffsetY {
                self.zoomInOffsetY = zoomInOffsetY
            }
        }
        else {
            print("JSON decode error")
            return nil
        }
    }
    
    public func projectPoint(objectPoint: Point3D) -> Point3D {
        let objectPoint = objectPoint.copy() as! Point3D
        objectPoint.z = objectPoint.z == 0 ? Double(camHeight) : objectPoint.z
        let pot = worldPointToCamera3DPoint(objectPoint: objectPoint)
        var pot2D = projectTo2D(objectPoint: pot)
        pot2D = distortionToLdc(objectPoint: pot2D, objectPoint3D: objectPoint)
        
        return pot2D
    }
    
    func getCamHeight() -> Int {
        return camHeight
    }
    
    func getImgSize() -> CGSize {
        if (isFisheye == nil) {
            return CGSize(width: modResolutionH, height: resolutionW)
        }
        else {
            return CGSize(width: orgHeight, height: orgWidth)
        }
    }
    
    func worldPointToCamera3DPoint(objectPoint: Point3D) -> Point3D {
        return  angleAny(objectPoint: objectPoint)
    }
    
    func projectTo2D(objectPoint: Point3D) -> Point3D {
        if (isFisheye == nil)
        {
            return lens3DNormal(objectPoint: objectPoint)
        }
        else if (isFisheye == 1)
        {
            return lensFisheye(objectPoint: objectPoint)
        }
        else
        {
            return lensNormal(objectPoint: objectPoint)
        }
    }
    
    func distortionToLdc(objectPoint: Point3D, objectPoint3D: Point3D) -> Point3D {
        if (moduleName != nil && oriOToLdcTable != nil) {
            return ldcOn(objectPoint: objectPoint, objectPoint3D: objectPoint3D)
        }
        else {
            return ldcOff(objectPoint: objectPoint, objectPoint3D: objectPoint3D)
        }
    }
    
    func setTranslation() {
        //let translationToMaster =  "{\"2DtranslationToMaster\":{\"TranslationX\":0,\"TranslationY\":0},\"Status\":200}"
        translationX = 0
        translationY = 0
    }
    
    func angleAny(objectPoint: Point3D) -> Point3D {
        return Point3D(x: objectPoint.x,
                       y: cos(Double(angle) * .pi / 180.0) * objectPoint.y + sin(Double(angle) * .pi / 180.0) * objectPoint.z,
                       z: -sin(Double(angle) * .pi / 180.0) * objectPoint.y + cos(Double(angle) * .pi / 180.0) * objectPoint.z)
    }
    
    func lens3DNormal(objectPoint: Point3D) -> Point3D {
        let dst = Point3D(x: objectPoint.x * f / objectPoint.z + cx,
                          y: objectPoint.y * f / objectPoint.z + cy,
                          z: 0.0);
        dst.x = dst.x - Double(offsetX)
        dst.y = dst.y - Double(offsetY)
        return dst
    }
    
    func lensFisheye(objectPoint: Point3D) -> Point3D {
        let objectZ = objectPoint.z != 0 ? 1.0 / objectPoint.z : 1.0
        let objectX = objectPoint.x * objectZ
        let objectY = objectPoint.y * objectZ
        let r2 = objectX * objectX + objectY * objectY
        let r = sqrt(r2)
        
        // Angle of the incoming ray:
        let theta = atan(r)
        let theta2 = theta * theta, theta3 = theta2 * theta, theta4 = theta2 * theta2, theta5 = theta4 * theta, theta6 = theta3 * theta3, theta7 = theta6 * theta, theta8 = theta4 * theta4, theta9 = theta8 * theta
        let theta_d = theta + k[0] * theta3 + k[1] * theta5 + k[2] * theta7 + k[3] * theta9
        let inv_r = r > 1e-8 ? 1.0 / r : 1.0
        let cdist = r > 1e-8 ? theta_d * inv_r : 1.0
        let xd1 = objectX * cdist
        let xd2 = objectY * cdist
        let imageX = (xd1 * fx + cx)
        let imageY = (xd2 * fy + cy)
        
        return Point3D(x: imageX, y: imageY, z: 0.0)
    }
    
    func lensNormal(objectPoint: Point3D) -> Point3D {
        let objectZ = objectPoint.z != 0 ? 1.0 / objectPoint.z : 1.0
        let objectX = objectPoint.x * objectZ
        let objectY = objectPoint.y * objectZ
        let r2 = objectX * objectX + objectY * objectY
        let r4 = r2 * r2
        let r6 = r4 * r2
        let a1 = 2 * objectX * objectY
        let a2 = r2 + 2 * objectX * objectX
        let a3 = r2 + 2 * objectY * objectY
        let cdist = 1 + k[0] * r2 + k[1] * r4 + k[4] * r6
        let icdist2 = 1.0 / (1 + k[5] * r2 + k[6] * r4 + k[7] * r6)
        let xd = objectX * cdist * icdist2 + k[2] * a1 + k[3] * a2 + k[8] * r2 + k[9] * r4
        let yd = objectY * cdist * icdist2 + k[2] * a3 + k[3] * a1 + k[10] * r2 + k[11] * r4
        let imageX = (xd * fx + cx)
        let imageY = (yd * fy + cy)
        
        return Point3D(x: imageX, y: imageY, z: 0.0)
    }
    
    func ldcOn(objectPoint: Point3D, objectPoint3D: Point3D) -> Point3D {
        guard let oriOToLdcTable = oriOToLdcTable
            else { return Point3D(x: 0.0, y: 0.0, z: 0.0) }
        
        let scaleX = 4.0
        let scaleY = 4.0
        let tableSize = Point3D(x: 1280.0 / scaleX, y: (720.0 + 120.0) / scaleY, z: 0.0)
        let pointDistort = objectPoint.copy() as! Point3D
        pointDistort.x = max(pointDistort.x, 0.0)
        pointDistort.y = max(pointDistort.y, 0.0)
        pointDistort.x = min(pointDistort.x, 1280.0 - 1.0)
        pointDistort.y = min(pointDistort.y, 720.0 + 120.0 - 1.0)
        
        let tableIndexX = floor(pointDistort.x / scaleX)
        let tableIndexY = floor(pointDistort.y / scaleY)
        let tableOffset = Int(tableIndexY * tableSize.x + tableIndexX)
        let tableOffsetRightDouble = tableIndexY * tableSize.x + min(tableIndexX + 1.0, tableSize.x - 1.0)
        let tableOffsetRight = Int(tableOffsetRightDouble)
        let tableOffsetDownDouble = min(tableIndexY + 1.0, tableSize.y - 1.0) * tableSize.x + tableIndexX
        let tableOffsetDown = Int(tableOffsetDownDouble)
        
        var potLdcX = oriOToLdcTable[tableOffset * 2] + (oriOToLdcTable[tableOffsetRight * 2] - oriOToLdcTable[tableOffset * 2]) * (pointDistort.x.truncatingRemainder(dividingBy: scaleX)) / scaleX
        var potLdcY = oriOToLdcTable[tableOffset * 2 + 1] + (oriOToLdcTable[tableOffsetDown * 2 + 1] - oriOToLdcTable[tableOffset * 2 + 1]) * (pointDistort.y.truncatingRemainder(dividingBy: scaleY)) / scaleY
        
        if ((oriOToLdcTable[tableOffset * 2] < 0) || (oriOToLdcTable[tableOffsetRight * 2] < 0)) {
            potLdcX = max(oriOToLdcTable[tableOffset * 2], oriOToLdcTable[tableOffsetRight * 2])
        }
        
        if ((oriOToLdcTable[tableOffset * 2] > 1280) || (oriOToLdcTable[tableOffsetRight * 2] > 1280)) {
            potLdcX = min(oriOToLdcTable[tableOffset * 2], oriOToLdcTable[tableOffsetRight * 2])
        }
        
        potLdcY = potLdcY - 156
        potLdcX = max(potLdcX, 0)
        potLdcY = max(potLdcY, 0)
        potLdcX = min(potLdcX, 1280 - 1)
        //potLdcY = min(potLdcY, 720 - 1)
        
        if (objectPoint3D.z > 800)
        {
            let head = objectPoint3D.copy() as! Point3D
            head.z = head.z - 1650
            let pointCamera2 = worldPointToCamera3DPoint(objectPoint: head)
            let potDistort2 = projectTo2D(objectPoint: pointCamera2)
            let potLdc2 = distortionToLdc(objectPoint: potDistort2, objectPoint3D: objectPoint3D)
            potLdcX = potLdc2.x
        }
        
        return Point3D(x: potLdcX, y: potLdcY, z: 0.0)
    }
    
    func ldcOff(objectPoint: Point3D, objectPoint3D: Point3D) -> Point3D {
        return objectPoint
    }
}
