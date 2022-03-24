//
//  RxNetworkService.swift
//  RxNetworkService
//
//  Created by AdlibBeats on 13.03.2021.
//  Copyright © 2021 AdlibBeats. All rights reserved.
//

import RxCocoa
import RxSwift
import SWXMLHash

// MARK: RxNetworkService

public enum RxNetworkServiceError: Error {
    public enum Status: Int {
        case badRequest = 400
        case unauthorized = 401
        case notFound = 404
        case requestTimeout = 408
        case internalServerError = 500
        case notImplemented = 501
        case badGateway = 502
        case serviceUnavailable = 503
        case unknown
    }
    case invalidUrl(String)
    case invalidData(Data)
    case requestError(Status)

    var description: String {
        switch self {
        case .invalidUrl(let string): return "Invalid url string: \(string)"
        case .invalidData(let data): return "Invalid data: \(data)"
        case .requestError(let status): return "Error status code: \(status.rawValue > 0 ? "\(status.rawValue)" : "unknown")"
        }
    }
}

private extension ObserverType {
    func onError(_ error: RxNetworkServiceError) {
        self.on(.error(error))
    }
}

public protocol RxNetworkServiceProtocol: AnyObject {
    func fetchUrl(from string: String) -> Observable<URL>
    func fetchURLRequest(
        from url: String,
        contentType: RxNetworkService.ContentType,
        charset: RxNetworkService.Charset,
        httpMethod: RxNetworkService.HTTPMethod,
        body: Data?
    ) -> Observable<URLRequest>
    func fetchURLRequest(
        from url: String,
        contentType: RxNetworkService.ContentType,
        charset: RxNetworkService.Charset,
        httpMethod: RxNetworkService.HTTPMethod,
        body: String
    ) -> Observable<URLRequest>
    func fetchResponse(from urlRequest: URLRequest) -> Observable<(response: HTTPURLResponse, data: Data)>
    func fetchDecodableOutput<Output: Decodable>(response: HTTPURLResponse, data: Data) -> Observable<Output>
    func fetchStringResponse(response: HTTPURLResponse, data: Data) -> Observable<String>
    func fetchXMLOutput<Output: XMLOutput>(from stringResponse: String) -> Observable<Output>
    func fetchStatus(response: HTTPURLResponse, data: Data) -> Observable<RxNetworkService.Response>
}

open class RxNetworkService {
    public struct Response {
        let statusCode: Int
        let allHeaderFields: [AnyHashable: Any]
        let data: Data

        var dataString: String {
            String(data: data, encoding: .utf8) ?? ""
        }
    }

    public enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    public enum ContentType: String {
        case json
        case xml
    }

    public enum Charset: String {
        case utf8 = "utf-8"
    }

    public enum Logging {
        case request
        case response
        case error
    }

    public var urlSession = URLSession.shared
    public var logging: [Logging] = [.request, .response, .error]

    public init() {

    }

    private func logRequest(request: URLRequest) {
        guard
            logging.contains(.request),
            let httpMethod = request.httpMethod,
            let httpBody = request.httpBody
        else { return }

        #if DEBUG
        print("*** 🟡 Request ***\nHTTPMethod: \(httpMethod)\nHTTPBody: \(String(data: httpBody, encoding: .utf8) ?? httpBody.description)")
        #endif
    }

    private func logResponse(response: HTTPURLResponse, data: Data) {
        guard logging.contains(.response) else { return }

        #if DEBUG
        print("*** 🟢 Response ***\nStatus code: \(response.statusCode)\nData: \(String(data: data, encoding: .utf8) ?? data.description)")
        #endif
    }

    private func logError(error: Error) {
        guard logging.contains(.error) else { return }

        #if DEBUG
        print("*** 🔴 Error ***\nValue: \({ ($0 as? RxNetworkServiceError) ?? $0 }(error))")
        #endif
    }
}

extension RxNetworkService: RxNetworkServiceProtocol {
    public func fetchUrl(from string: String) -> Observable<URL> {
        Observable.create {
            if let url = URL(string: string) { $0.onNext(url) }
            else { $0.onError(.invalidUrl(string)) }
            return Disposables.create()
        }.do(onError: logError)
    }

    public func fetchURLRequest(
        from url: String,
        contentType: RxNetworkService.ContentType,
        charset: RxNetworkService.Charset,
        httpMethod: RxNetworkService.HTTPMethod,
        body: Data?
    ) -> Observable<URLRequest> {
        fetchUrl(from: url).map {
            var urlRequest = URLRequest(url: $0)
            urlRequest.httpMethod = httpMethod.rawValue
            urlRequest.addValue(
                "text/\(contentType.rawValue); charset=\(charset.rawValue)",
                forHTTPHeaderField: "Content-Type"
            )
            urlRequest.httpBody = body
            return urlRequest
        }.do(onNext: logRequest)
    }
    
    public func fetchURLRequest(
        from url: String,
        contentType: RxNetworkService.ContentType,
        charset: RxNetworkService.Charset,
        httpMethod: RxNetworkService.HTTPMethod,
        body: String
    ) -> Observable<URLRequest> {
        fetchUrl(from: url).map {
            var urlRequest = URLRequest(url: $0)
            urlRequest.httpMethod = httpMethod.rawValue
            urlRequest.addValue(
                "text/\(contentType.rawValue); charset=\(charset.rawValue)",
                forHTTPHeaderField: "Content-Type"
            )
            if !body.isEmpty {
                urlRequest.httpBody = body.data(
                    using: .utf8,
                    allowLossyConversion: false
                )
            }
            return urlRequest
        }.do(onNext: logRequest)
    }
    
    public func fetchResponse(from urlRequest: URLRequest) -> Observable<(response: HTTPURLResponse, data: Data)> {
        urlSession.rx.response(request: urlRequest).do(onNext: logResponse, onError: logError)
    }
    
    public func fetchDecodableOutput<Output: Decodable>(response: HTTPURLResponse, data: Data) -> Observable<Output> {
        Observable.create {
            do { $0.onNext(try JSONDecoder().decode(Output.self, from: data)) }
            catch { $0.onError(error) }
            return Disposables.create()
        }.do(onError: logError)
    }
    
    public func fetchStringResponse(response: HTTPURLResponse, data: Data) -> Observable<String> {
        Observable.create {
            if let result = String(
                data: data,
                encoding: .utf8
            ) { $0.onNext(result) }
            else { $0.onError(.invalidData(data)) }
            return Disposables.create()
        }.do(onError: logError)
    }
    
    public func fetchXMLOutput<Output: XMLOutput>(from stringResponse: String) -> Observable<Output> {
        Observable.create {
            do { $0.onNext( try RxNetworkService.XML.Mapper.parse(Output.self, from: stringResponse).value()) }
            catch { $0.onError(error) }
            return Disposables.create()
        }.do(onError: logError)
    }
    
    public func fetchStatus(response: HTTPURLResponse, data: Data) -> Observable<RxNetworkService.Response> {
        Observable.create {
            switch response.statusCode {
            case 200...299: $0.onNext(.init(statusCode: response.statusCode, allHeaderFields: response.allHeaderFields, data: data))
            case let value: $0.onError(.requestError(.init(rawValue: value) ?? .unknown))
            }
            return Disposables.create()
        }.do(onError: logError)
    }
}

// MARK: XMLMapper

public typealias XMLModel = XMLIndexer
public typealias XMLOutput = XMLIndexerDeserializable

infix operator <- : DefaultPrecedence

extension String {
    public static func <- (name: Self, value: RxNetworkService.XML.Mapper.Property.Value) -> RxNetworkService.XML.Mapper.Property {
        .init(name: name, value: value)
    }
}

public protocol XMLProtocol {
    var xml: String { get }
}

public protocol XMLInput: XMLProtocol {
    func mapping() -> RxNetworkService.XML.Mapper.Property
}

extension XMLInput {
    public var xml: String {
        RxNetworkService.XML.Mapper(value: mapping().xml(mode: .parent)).xml
    }
}

public protocol XMLMapperProtocol: XMLProtocol {
    func xml(mode: RxNetworkService.XML.Mapper.KindMode) -> String
}

public protocol XMLValueMapperProtocol: XMLMapperProtocol {
    var value: String { get }
}

extension RxNetworkService {
    public enum XML {
        public struct Mapper: XMLValueMapperProtocol {
            public enum KindMode {
                case parent
                case child
                case unknown
            }
            
            public static func parse<Output: XMLOutput>(_ type: Output.Type, from stringResponse: String) throws -> XMLModel {
                try XMLHash.parse(stringResponse)
                    .byKey("SOAP-ENV:\(String(describing: Envelope.self))")
                    .byKey("SOAP-ENV:\(String(describing: Body.self))")
                    .byKey("ns1:\(String(describing: type))")
            }
            
            public struct Body: XMLValueMapperProtocol {
                public var xml: String { xml(mode: .child) }
                public func xml(mode: KindMode) -> String {
                    "<SOAP-ENV:\(String(describing: Body.self))>\(value)</SOAP-ENV:\(String(describing: Body.self))>"
                }
                public let value: String
            }
            
            public struct Envelope: XMLValueMapperProtocol {
                private let env: String
                private let enc: String
                private let xsi: String
                private let xsd: String
                
                public init(
                    value: String,
                    env: String = "http://schemas.xmlsoap.org/soap/envelope/",
                    enc: String = "http://schemas.xmlsoap.org/soap/encoding/",
                    xsi: String = "http://www.w3.org/2001/XMLSchema-instance",
                    xsd: String = "http://www.w3.org/2001/XMLSchema"
                ) {
                    self.value = value
                    self.env = env
                    self.enc = enc
                    self.xsi = xsi
                    self.xsd = xsd
                }
                
                public var xml: String { xml(mode: .child) }
                public func xml(mode: KindMode) -> String {
                    "<SOAP-ENV:\(String(describing: Envelope.self)) xmlns:SOAP-ENV=\"\(env)\" xmlns:SOAP-ENC=\"\(enc)\" xmlns:xsi=\"\(xsi)\" xmlns:xsd=\"\(xsd)\">\(value)</SOAP-ENV:\(String(describing: Envelope.self))>"
                }
                public let value: String
            }
            
            public struct Header: XMLMapperProtocol {
                public enum Encoding: String {
                    case utf8 = "UTF-8"
                }
                private let version: Double
                private let encoding: Encoding
                
                public init(version: Double = 1.0, encoding: Encoding = .utf8) {
                    self.version = version
                    self.encoding = encoding
                }
                
                public var xml: String { xml(mode: .child) }
                public func xml(mode: KindMode) -> String {
                    "<?xml version=\"\(String(format: "%.1f", version))\" encoding=\"\(encoding.rawValue)\"?>"
                }
            }
            
            public struct Property: XMLValueMapperProtocol {
                public struct Value {
                    let value: String
                    let parentUrl: String
                    
                    public init(value: String, parentUrl: String) {
                        self.value = value
                        self.parentUrl = parentUrl
                    }
                    
                    public init(value: String) {
                        self.init(value: value, parentUrl: "")
                    }
                }
                
                private let name: String
                private let parentUrl: String
                
                public init(name: String, value: Value) {
                    self.name = name
                    self.value = value.value
                    self.parentUrl = value.parentUrl
                }
                
                public var xml: String { xml(mode: .child) }
                public func xml(mode: KindMode) -> String {
                    switch mode {
                    case .child: return "<m:\(name)>\(value)</m:\(name)>"
                    case .parent: return "<m:\(name) xmlns:m=\"\(parentUrl)\">\(value)</m:\(name)>"
                    case .unknown: return "<\(name)>\(value)</\(name)>"
                    }
                }
                public let value: String
            }
            
            public let value: String
            public var xml: String { xml(mode: .child) }
            public func xml(mode: KindMode) -> String {
                [Header().xml, Envelope(value: Body(value: value).xml).xml].joined()
            }
        }
    }
}
