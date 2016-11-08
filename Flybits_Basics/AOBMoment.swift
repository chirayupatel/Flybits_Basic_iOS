//
//  AOBMoment.swift
//  Flybits_Basics
//
//  Created by Archuthan Vijayaratnam on 2016-11-07.
//  Copyright © 2016 Flybits. All rights reserved.
//

import UIKit
import FlybitsSDK

@objc public protocol Parsable {
}

public protocol AOBContentType {
    init?(data: Any)
}

extension NSDictionary : Parsable { }
extension NSArray : Parsable { }

/**
 Use AOBContent for swift -- has support for Generics
 Use AOBRootItem (FMAOBRootItem) for ObjC -- returns NSDictionary/NSArray
 */
@objc(FMAOBContentData)
public class AOBContentBaseData: NSObject, ResponseObjectSerializable {
    fileprivate var localized:[String: Parsable] = [:]
    
    public var templateId: String
    
    public var availableLanguages: [String] {
        get {
            return localized.lazy.flatMap({ $0.0 })
        }
    }
    
    public required init?(response: HTTPURLResponse, representation: AnyObject) {
        guard
            let data = representation as? [String: AnyObject],
            let templateId = data.jsonObject("templateId", String.self),
            let localized = data.jsonObject("localizedKeyValuePairs", [String: AnyObject].self)
            else {
                return nil
        }
        self.templateId = templateId
        super.init()
        for (lang, value) in localized {
            if let root = value as? [String: AnyObject],
                let rootObj = root["root"],
                let actualObj = self.parseRootObject(data: rootObj) {
                self.localized[lang.lowercased()] = actualObj
            }
        }
    }
    
    fileprivate func parseRootObject(data: Any) -> Parsable? {
        return nil
    }
    
    public override var description: String {
        return localized.map({
            return "\($0.key):\($0.value)"
        }).joined(separator: "\n")
    }
}

public class AOBContent<T: Parsable> : AOBContentBaseData where T: AOBContentType {
    fileprivate override func parseRootObject(data: Any) -> Parsable? {
        return T.init(data: data)
    }
    public func localizedItem(lang: String) -> T? {
        return self[lang]
    }
    public var en: T? {
        return self["en"]
    }
    public func localizedForDevice() -> T? {
        if let lang = Locale.autoupdatingCurrent.languageCode {
            return self[lang]
        }
        return nil
    }
    subscript(languageCode: String) -> T? {
        return self.localized[languageCode.lowercased()] as? T
    }
}

@objc(FMAOBRootItem)
public class AOBRootItem : AOBContentBaseData {
    fileprivate override func parseRootObject(data: Any) -> Parsable? {
        if let data = data as? [String: AnyObject] as Parsable? {
            return data
        } else if let data = data as? [AnyObject] as Parsable? {
            return data
        }
        return nil
    }
    @objc(localizedItemForLang:)
    public func localizedItem(lang: String) -> Any? {
        return self.localized[lang.lowercased()]
    }
    public var enDictionary: [String: AnyObject]? {
        return self.localizedItem(lang: "en") as? [String: AnyObject]
    }
    public var enArray: [AnyObject]? {
        return self.localizedItem(lang: "en") as? [AnyObject]
    }
    public func localizedForDevice() -> Any? {
        if let lang = Locale.autoupdatingCurrent.languageCode {
            return self.localizedItem(lang: lang)
        }
        return nil
    }
}


@objc(FMAOBRequest)
public class AOBRequest : NSObject {
    public class func getData<T: Parsable>(moment: Moment, template: T.Type, completion: @escaping (_ data: AOBContent<T>?, _ error: NSError?) -> Void) -> Requestable {
        
        let url = "\(moment.launchURL)/KeyValuePairs/AsMetadata"
        let req = CustomRequester.GET(
            url: url,
            headers: nil,
            type: AOBContent<T>.self,
            completion: completion
        )
        return req.requestable
    }
    
    /*
     Note: For Swift, use `AOBMomentRequest.getData<T: Parsable>(moment: Moment, template: T.Type, completion: @escaping (_ data: AOBContent<T>?, _ error: NSError?) -> Void) -> Requestable`
     */
    @objc
    public class func getData(moment: Moment, completion: @escaping (_ data: AOBRootItem?, _ error: NSError?) -> Void) -> FlybitsRequest {
        let url = "\(moment.launchURL)/KeyValuePairs/AsMetadata"
        
        let req = CustomRequester.GET(
            url: url,
            headers: nil,
            type: AOBRootItem.self,
            completion: { (data: AOBRootItem?, error) in
                completion(data, error)
        }
        )
        return req.requestable.execute()
    }
}


fileprivate struct CustomRequester : Requestable {
    
    private enum CustomRequesterType {
        case GET
        case POST
        case DELETE
        case PUT
    }
    
    private var customRequesterType: CustomRequesterType
    private init(type: CustomRequesterType, url: String) {
        self.customRequesterType = type
        self.baseURI = url
        self.encoding = .url
        self.method = .GET
    }
    
    static func GET<T: ResponseObjectSerializable>(url: String, query: [String: AnyObject] = [:], headers: [String: String]?, type: T.Type, completion: @escaping (_ data: T?, _ error: NSError?)->Void) -> (requestable: Requestable, flybitsRequest: FlybitsRequest) {
        
        var req = CustomRequester.init(type: .GET, url: url)
        req.method = .GET
        req.requestType = .custom
        if let headers = headers {
            req.headers = headers
        }
        req.encoding = .url
        req.parameters = query
        
        let freq = req.response { (request, response, data: T?, error) in
            completion(data, error)
        }
        return (req, freq)
    }
    
    public var requestType: FlybitsRequestType = .custom
    public var baseURI: String
    public var path: String = ""
    public var headers: [String : String] = ["Accept-Language" : "en"]
    public var encoding: HTTPEncoding
    public var method: HTTPMethod
    public var parameters: [String : AnyObject]?
    public func execute() -> FlybitsRequest {
        return FlybitsRequest.init(self.urlRequest)
    }
}


internal extension Dictionary {
    func jsonObject<T>(_ key: Key, _ type: T.Type = T.self) -> T? {
        return self[key] as? T
    }
    
    func jsonObject<T: Parsable & AOBContentType>(_ key: Key, _ type: T.Type = T.self) -> T? {
        guard let val = self[key] else {
            return nil
        }
        return T.init(data: val)
    }
    
    func jsonObject<T: Parsable & AOBContentType>(_ key: Key, _ type: [T].Type = [T].self) throws -> [T] {
        guard let values = self[key] as? [Any] else {
            throw NSError.init(domain: "com.flybits.app", code: -111, userInfo: [NSLocalizedDescriptionKey: "expected array of items"])
        }
        var items = [T]()
        for f in values {
            guard let item = T.init(data: f) else {
                throw NSError.init(domain: "com.flybits.app", code: -111, userInfo: [NSLocalizedDescriptionKey: "unable to parse \(type)"])
            }
            items.append(item)
        }
        return items
    }
    
    func htmlDecodedString(_ key: Key) -> String? {
        return self.jsonObject(key, String.self)?.htmlDecodedString
    }
}

