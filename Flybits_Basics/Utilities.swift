//
//  Utilities.swift
//  Flybits_Basics
//
//  Created by Archuthan Vijayaratnam on 2016-11-03.
//  Copyright © 2016 Flybits. All rights reserved.
//

import Foundation
import FlybitsSDK

/*
 Anonymous Login
 */
extension SessionRequest {
    static func AnonymousLogin(completion: @escaping (_ user: User?, _ error: NSError?) -> Void) -> Requestable? {
        guard let data = getSavedLoginData() else {
            _ = createNewAccount { (user, password, error) in
                if error != nil {
                    completion(nil, error)
                    return
                }
                completion(user, error)
            }?.execute()
            return nil
        }
        let task = SessionRequest.login(email: data.email, password: data.password, rememberMe: false, fetchJWT: true, completion: completion)
        return task
    }
    
    private static func createNewAccount(completion: @escaping (_ user: User?, _ password: String, _ error: NSError?) -> Void) -> Requestable? {
        let email = NSUUID.init().uuidString.appending("@flybits.com")
        let password = NSUUID.init().uuidString
        
        let account = AccountQuery.init()
        account.email = email
        account.password = password
        
        let req = AccountRequest.register(account) { (user, error) in
            guard error == nil else {
                completion(user, password, error)
                return
            }
            saveLoginData(email: email, password: password)
            _ = SessionRequest.logout(completion: { (success, error) in
                guard success else {
                    completion(user, password, error)
                    return
                }
                _ = SessionRequest.login(email: email, password: password, rememberMe: false, fetchJWT: true, completion: { (user, error) in
                    completion(user, password, error)
                }).execute()
            }).execute()
        }
        return req
    }
    
    private static func saveLoginData(email: String, password: String) {
        let u = UserDefaults.standard
        u.setValue(email, forKey: "login.email")
        u.setValue(password, forKey: "login.password")
        u.synchronize()
    }
    
    private static func getSavedLoginData() -> (email: String, password: String)? {
        guard
            let email = UserDefaults.standard.string(forKey: "login.email"),
            let password = UserDefaults.standard.string(forKey: "login.password")
            else {
                return nil
        }
        return (email, password)
    }
}

fileprivate enum AnonymousLoginError : Int {
    case creatingAccount = -100
    
    var nsError: NSError? {
        return NSError.init(domain: "com.flybits.anonymous", code: self.rawValue, userInfo: [NSLocalizedDescriptionKey: "Error creating anonymouse account"])
    }
}
