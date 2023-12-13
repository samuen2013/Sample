//
//  ViewCellStatus.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2022/5/13.
//

import SwiftUI

enum PlaybackStatus {
    case play
    case pause
    case rewind
}

enum ReconnectAction {
    case startLive
    case startPlayback(Date)
}

enum PlaybackSpeed: CaseIterable {
    case quarter
    case half
    case normal
    case double
//    case quadruple
//    case octuple
    
    var display: LocalizedStringKey {
        switch self {
        case .quarter: return "0.25x"
        case .half: return "0.5x"
        case .normal: return "Normal"
        case .double: return "2x"
//        case .quadruple: return "4x"
//        case .octuple: return "8x"
        }
    }
    
    var value: Float {
        switch self {
        case .quarter: return 0.25
        case .half: return 0.5
        case .normal: return 1.0
        case .double: return 2.0
//        case .quadruple: return 4.0
//        case .octuple: return 8.0
        }
    }
}

enum ConnectStreamingError: Equatable, Error {
    case exceedLimit
}
