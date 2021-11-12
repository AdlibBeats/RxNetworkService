//
//  RxMyNetworkService.swift
//  RxNetworkService
//
//  Created by Andrew on 13.03.2021.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import RxSwift
import RxCocoa
import RxNetworkService

extension String {
    static func <- (name: Self, value: String) -> RxNetworkService.XML.Mapper.Property {
        .init(name: name, value: .init(value: value, parentUrl: "http://www.soap-url..."))
    }
}

protocol RxMyNetworkServiceProtocol: RxNetworkServiceProtocol {
    func fetchMyJSONOutput() -> Observable<RxMyNetworkService.MyJSONOutput>
    func fetchMyXMLOutput() -> Observable<RxMyNetworkService.MyXMLOutput>
}

final class RxMyNetworkService: RxNetworkService {
    fileprivate var sessionToken = ""
    fileprivate var secretKey = ""
    
    enum Config: String {
        case baseUrl = "https://base-url"
        case jsonUrl = "/url"
        case xmlUrl = "/url.php?wsdl"
    }
}

extension RxMyNetworkService: RxMyNetworkServiceProtocol {
    
    // MARK: fetch JSONOutput
    func fetchMyJSONOutput() -> Observable<RxMyNetworkService.MyJSONOutput> {
        fetchURLRequest(
            from: [Config.baseUrl.rawValue, Config.jsonUrl.rawValue].joined(),
            contentType: .json,
            charset: .utf8,
            httpMethod: .get,
            body: try? JSONEncoder().encode(MyJSONInput(test: "hello")) // nil // String or Data? (Codable)
        )
        .flatMapLatest(fetchResponse)
        .flatMapLatest(fetchDecodableOutput)
    }
    
    // MARK: fetch XMLOutput
    func fetchMyXMLOutput() -> Observable<MyXMLOutput> {
        fetchURLRequest(
            from: [Config.baseUrl.rawValue, Config.xmlUrl.rawValue].joined(),
            contentType: .xml,
            charset: .utf8,
            httpMethod: .post,
            body: MyXMLInput(
                token: sessionToken,
                route: true,
                crypt: secretKey
            ).xml
        )
        .flatMapLatest(fetchResponse)
        .flatMapLatest(fetchStringResponse)
        .flatMapLatest(fetchXMLOutput)
    }
}

extension RxMyNetworkService {
    
    // MARK: JSON Input struct
    struct MyJSONInput: Encodable {
        let test: String
        
        enum CodingKeys: String, CodingKey {
            case test = "TEST"
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(test, forKey: .test)
        }
    }
    
    // MARK: JSON Output struct
    struct MyJSONOutput: Decodable {
        var date: Date?
        var value: String?
        var tests: [String]?
        
        enum CodingKeys: String, CodingKey {
            case date = "DATE"
            case value = "VALUE"
            case tests = "TESTS"
        }
        
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            let dateFormatter: DateFormatter = {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return dateFormatter
            }()
            
            date = dateFormatter.date(from: ((try? values.decode(String.self, forKey: .date)) ?? ""))
            value = try? values.decode(String.self, forKey: .value)
            tests = try? values.decode([String].self, forKey: .tests)
        }
    }
    
    // MARK: XML Input struct
    struct MyXMLInput: XMLInput {
        let token: String
        let route: Bool
        let crypt: String
        
        func mapping() -> XML.Mapper.Property {
            (String(describing: MyXMLInput.self) <- {
                [
                    "token" <- token,
                    "route" <- (route ? "Y" : "N"),
                    "crypt" <- [token, route ? "Y" : "N", crypt].joined() /* .crypt() */
                ]
            }().map { $0.xml }.joined())
        }
    }
    
    // MARK: XML Output struct
    struct MyXMLOutput: XMLOutput {
        let value: String
        
        static func deserialize(_ model: XMLModel) throws -> MyXMLOutput {
            try MyXMLOutput(
                value: model["ns1:value"].value()
            )
        }
    }
}
