//
//  CharmanderError.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2022/4/18.
//

import Foundation

enum CharmanderError: Error, Equatable {
    case newVersionAvailable
    case failToConnectServer
    case accessDenied
    case outOfOrganization
    case invalidUserID
    case invalidOrgID
    case newToVortex
    case serviceIsBusy
    case invalidLicense
    
    case invalidDevice
    case invalidNVR
    case invalidRequest
    case invalidResponse
    case invalidHttpStatusCode(Int?)
    case invalidSnapshot
    case invalidThumbnail
    case invalidMetadata
    case invalidURL
    case invalidAccessToken
    case invalidSearchResult
    case invalidDate
    case invalidRemoteConfigValue
    
    case invalidAWSS3TransferUtility
    case existedAWSS3TransferUtility
    
    case emptyEmail
    case invalidEmail
    case emptyPassword
    case invalidInput
    case isBlocked
    case sessionExpired
    case isSignOut
    case needToConfirmSignUp
    case needToConfirmSignIn
    case invalidOrganizationName
    
    case connectDeviceFail(ConnectDeviceFailReason)
    case addDeviceFail(AddDeviceFailReason)
    case updateDeviceFail
    case deleteDeviceFail
    case moveDeviceFail
    
    case archiveLimit
    case thumbnailNotFound
    case permissionDenied
    case publishFail
    
    case notImplement
    case notSupport
    
    case organizationHasOtherUsers
    case organizationHasDevices
    
    // MQTTManager
    case invalidSignalingEssentials
    case invalidAWSServiceConfiguration
}

enum AddDeviceFailReason: Equatable {
    case isUsed
    case invalidFormat
    case failToConnect
}

enum ConnectDeviceFailReason: Equatable {
    case userCallCancel
    case tooManyConnections
    case failToConnect
}

enum SetPasswordFailReason: Equatable {
    case incorrect
    case notMatch
    case failToConnect
}
