//
//  ViewController.swift
//  Flybits_Basics
//
//  Created by Archuthan Vijayaratnam on 2016-11-02.
//  Copyright © 2016 Flybits. All rights reserved.
//

import UIKit
import FlybitsSDK

class LoginViewController: UIViewController {
    @IBOutlet weak var fieldEmail: UITextField!
    @IBOutlet weak var fieldPassword: UITextField!
    
    @IBOutlet weak var btnLogin: UIButton!
    @IBOutlet weak var btnLoginAnonymous: UIButton!
    @IBOutlet weak var btnLogout: UIButton!
    
    private var currentRequest: FlybitsRequest?
    
    //MARK: - View Controller setup -
    override func viewDidLoad() {
        super.viewDidLoad()
    }


    //MARK: - Contexts -
    private func enableContexts() {
        
    }
    
    private func disableContexts() {
        
    }
    
    private func displayError(message: String) {
        print(message)
    }

    //MARK: - User session management -
    @IBAction func buttonTapped(_ sender: UIButton?) {
        guard let sender = sender else {
            return
        }
        
        switch sender {
        case btnLogin:
            doLogin()
        case btnLoginAnonymous:
            doAnonymouseLogin()
        case btnLogout:
            doLogout()
        default:
            assertionFailure("missing a case")
        }
    }
    
    private func loginFinished(user: User?, error: NSError?) {
        OperationQueue.main.addOperation {
            
            guard let _ = user else {
//                print("localizedDescription", error?.localizedDescription ?? "")
//                print("localizedFailureReason", error?.localizedFailureReason ?? "")
//                print("localizedRecoveryOptions", error?.localizedRecoveryOptions ?? "")
                print("localizedRecoverySuggestion", error?.localizedRecoverySuggestion ?? "")
                self.displayError(message:  error?.localizedFailureReason ?? "Login failed")
                return
            }
            
            // we have valid session
            precondition(Session.sharedInstance.currentUser != nil, "User is not logged in?")
            
            self.enableContexts()
        }
    }

    private func logoutFinished() {
        precondition(Session.sharedInstance.currentUser == nil, "User is logged out, but has a 'currentUser' set")
    }
    
    private func doLogout() {
        _ = currentRequest?.cancel()
        currentRequest = SessionRequest.logout { [weak self](success, error) in
            self?.logoutFinished()
        }.execute()
    }
    
    private func doAnonymouseLogin() {
        _ = currentRequest?.cancel()
        currentRequest = SessionRequest.AnonymousLogin { [weak self](user, error) in
            self?.loginFinished(user: user, error: error)
        }?.execute()
    }
    
    private func doLogin() {
        guard
            let email = fieldEmail.text,
            let password = fieldPassword.text
        else {
            displayError(message: "missing email/password")
            return
        }
        _ = currentRequest?.cancel()
        currentRequest = SessionRequest.login(email: email, password: password, rememberMe: false, fetchJWT: true, completion: { [weak self](user, error) in
            self?.loginFinished(user: user, error: error)
        }).execute()
    }
}
