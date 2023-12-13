//
//  HttpRequestManager.swift
//  iOSCharmander
//
//  Created by 曹盛淵 on 2021/8/18.
//

import Alamofire
import SwiftUI

enum AFDownloadError: Error {
    case cancelled
    case forbidden
    case notFound
    case unknown
}

enum DownloadResult {
    case progress(Int64, Int64, Double)
    case completed(URL)
}

protocol HttpRequestProtocol {
    func send(_ url: URLConvertible, method: HTTPMethod, headers: HTTPHeaders?) async throws -> Data
    func send(_ url: URLConvertible, method: HTTPMethod, parameters: Parameters?, headers: HTTPHeaders?) async throws -> Data
    func send(_ url: URLConvertible, method: HTTPMethod, params: (some Encodable)?, headers: HTTPHeaders?) async throws -> Data
    
    func download(_ url: URL, saveTo filePath: URL) -> AsyncThrowingStream<DownloadResult, Error>
    func download(_ url: URL) async throws -> Data
    func postTechicalSupportRequest<Params>(_ params: Params?) async throws -> String where Params: Encodable
}

class HttpRequestManager: HttpRequestProtocol {
    private let logger = CharmanderFactory.makeLogger(type: .httpRequestManager)
    
    @AppStorage("connectDeviceUser") private var connectDeviceUser = "root"
    @AppStorage("connectDevicePassword") private var connectDevicePassword = "vssdtest123"
    
    func send(_ url: URLConvertible, method: HTTPMethod, headers: HTTPHeaders?) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            logger.trace(str: "send url: \(url), method: \(method)")
            AF.request(url, method: method, headers: headers)
                .authenticate(username: connectDeviceUser, password: connectDevicePassword)
                .validate()
                .response { response in
                    switch response.result {
                    case .success(let data):
                        self.logger.trace(str: "receive url: \(url), data: \(data?.asString ?? "nil")")
                        continuation.resume(returning: data ?? Data())
                    case .failure(let error):
                        self.logger.error(str: "receive url: \(url), error: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
    
    func send(_ url: URLConvertible, method: HTTPMethod, parameters: Parameters?, headers: HTTPHeaders?) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            logger.trace(str: "send url: \(url), method: \(method), with params: \(String(describing: parameters))")
            
            AF.request(url, method: method, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
                .authenticate(username: connectDeviceUser, password: connectDevicePassword)
                .validate()
                .response { response in
                    switch response.result {
                    case .success(let data):
                        self.logger.trace(str: "receive url: \(url), data: \(data?.asString ?? "nil")")
                        continuation.resume(returning: data ?? Data())
                    case .failure(let error):
                        self.logger.error(str: "receive url: \(url), error: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
        }
    }
    
    func send(_ url: URLConvertible, method: HTTPMethod, params: (some Encodable)?, headers: HTTPHeaders?) async throws -> Data {
        let paramsData = try JSONEncoder().encode(params)
        let httpParams = try JSONSerialization.jsonObject(with: paramsData) as? Parameters
        return try await send(url, method: method, parameters: httpParams, headers: headers)
    }
    
    func download(_ url: URL, saveTo filePath: URL) -> AsyncThrowingStream<DownloadResult, Error> {
        AsyncThrowingStream { continuation in
            try? FileManager.default.removeItem(at: filePath)
            FileManager.default.clearTmpDirectory()
            
            let destination: DownloadRequest.Destination = {_, _ in
                return (filePath, [.removePreviousFile])
            }
            let request = AF.download(url, to: destination)
                .downloadProgress {
                    continuation.yield(.progress($0.completedUnitCount, $0.totalUnitCount, $0.fractionCompleted))
                }
                .responseURL {
                    switch $0.result {
                    case .success(let url):
                        switch $0.response?.statusCode {
                        case 200:
                            continuation.yield(.completed(url))
                            continuation.finish()
                        case 403: continuation.finish(throwing: AFDownloadError.forbidden)
                        case 404: continuation.finish(throwing: AFDownloadError.notFound)
                        default: continuation.finish(throwing: AFDownloadError.unknown)
                        }
                    case .failure(let error):
                        switch error {
                        case .explicitlyCancelled: continuation.finish()
                        default: continuation.finish(throwing: AFDownloadError.unknown)
                        }
                    }
                }
            
            continuation.onTermination = { _ in
                request.cancel()
            }
        }
    }
    
    func download(_ url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            AF.download(url).responseData {
                switch $0.result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func postTechicalSupportRequest(_ params: (some Encodable)?) async throws -> String {
        let zendeskUrl = "https://vivotek.zendesk.com/api/v2/tickets.json"
        let headers: HTTPHeaders = [.authorization(bearerToken: CharmanderEnv.ZENDESK_TOKEN)]
        let data = try await send(zendeskUrl, method: .post, params: params, headers: headers)
        
        if let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: [String: Any]],
           let ticketID = json["ticket"]?["id"] as? Int {
            return String(ticketID)
        } else {
            throw CharmanderError.invalidResponse
        }
    }
}
