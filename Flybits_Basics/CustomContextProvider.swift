//
//  CustomContextProvider.swift
//  Flybits_Basics
//
//  Created by Archuthan Vijayaratnam on 2016-11-08.
//  Copyright © 2016 Flybits. All rights reserved.
//

import Foundation
import FlybitsSDK

fileprivate let notSetError = NSError.init(domain: "com.flybits.app", code: -1, userInfo: [NSLocalizedDescriptionKey: "Value is not set"])

public class CustomContextProvider: NSObject, ContextDataProvider {
    public let contextCategory: String = "ctx.sdk.demo"
    public var pollFrequency: Int32 = 60
    public var uploadFrequency: Int32 = 60
    public var priority: ContextDataPriority = .any
    public override init() {
        super.init()
    }
    public func refreshData(completion: @escaping ([String : AnyObject], NSError?) -> Void) {
        completion([:], notSetError)
    }
}

public class CustomNumberContextProvider : CustomContextProvider {
    public var number: NSNumber? = NSNumber.init(value: 32.0)
    public override func refreshData(completion: @escaping ([String : AnyObject], NSError?) -> Void) {
        guard let number = number else {
            super.refreshData(completion: completion)
            return
        }
        completion(["creditRating": number], nil)
    }
}

public class CustomStringContextProvider : CustomContextProvider {
    public var string: String? = "Welcome"
    public override func refreshData(completion: @escaping ([String : AnyObject], NSError?) -> Void) {
        guard let string = string else {
            super.refreshData(completion: completion)
            return
        }
        completion(["persona": string as AnyObject], nil)
    }
}


