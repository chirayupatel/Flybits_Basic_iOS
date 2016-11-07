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
    
    private var ibeaconContextDataProvider: iBeaconDataProvider?
    
    //MARK: - View Controller setup -
    override func viewDidLoad() {
        super.viewDidLoad()
    }


    //MARK: - Contexts -
    private func enableContexts() {
        let fiveMins = 1 * 60
        
        let cm = ContextManager.sharedManager
        _ = cm.register(.activity, priority: .any, pollFrequency: fiveMins, uploadFrequency: fiveMins)
        _ = cm.register(.audio, priority: .any, pollFrequency: fiveMins, uploadFrequency: fiveMins)
        _ = cm.register(.availability, priority: .any, pollFrequency: fiveMins, uploadFrequency: fiveMins)
        _ = cm.register(.battery, priority: .any, pollFrequency: fiveMins, uploadFrequency: fiveMins)
        _ = cm.register(.coreLocation, priority: .any, pollFrequency: fiveMins, uploadFrequency: fiveMins)
        // _ = cm.register(.iBeacon, priority: .any, pollFrequency: fiveMins, uploadFrequency: fiveMins)
        
        do {   // enable iBeacon context provider
            let coreLoc = CoreLocationDataProvider.init(asCoreLocationManager: true, withRequiredAuthorization: .authorizedAlways)
            _ = try? coreLoc.requestAlwaysAuthorization()
            
            let options = Set<iBeaconDataProvider.iBeaconOptions>.init(arrayLiteral: .monitoring, .ranging)
            let ibeacon = iBeaconDataProvider.init(apiFrequency: fiveMins, locationProvider: coreLoc, options: options)
            ibeacon.startBeaconQuery()
            
            _ = try? cm.register(ibeacon)
            
            ibeaconContextDataProvider = ibeacon
        }

        cm.startDataPolling()
    }
    
    private func disableContexts() {
        let cm = ContextManager.sharedManager
        cm.stopDataPolling()
 
        _ = cm.remove(.activity)
        _ = cm.remove(.audio)
        _ = cm.remove(.availability)
        _ = cm.remove(.battery)
        _ = cm.remove(.coreLocation)
        
        // _ = cm.remove(.iBeacon)
        
        if let ibeaconContextDataProvider = ibeaconContextDataProvider {
            _ = cm.remove(ibeaconContextDataProvider)
        }
        
    }
    // MARK:
    
    // MARK: Register For Push
    private func enablePush() {
        /*
        let apnsToken = apnsTokenReturnedByApple
        PushManager.sharedManager.configuration = PushConfiguration.configuration(with: .both, apnsToken: apnsToken, autoFetchData: true)
         */
        PushManager.sharedManager.configuration = PushConfiguration.configuration(with: .foreground)
    }
    
    private func disablePush() {
        PushManager.sharedManager.configuration = PushConfiguration.configuration(with: .none)
    }
    
    private func displayError(message: String) {
        print(message)
    }
    
    private func registerForPushStatus() {
        
        // remove any previously registered observers
        NotificationCenter.default.removeObserver(self, name: PushManagerConstants.PushConnected, object: nil)
        NotificationCenter.default.removeObserver(self, name: PushManagerConstants.PushDisconnected, object: nil)
        
        // register for push status
        NotificationCenter.default.addObserver(forName: PushManagerConstants.PushConnected, object: nil, queue: nil) { n in
            print(n.name.rawValue)
        }
        
        NotificationCenter.default.addObserver(forName: PushManagerConstants.PushDisconnected, object: nil, queue: nil) { n in
            print(n.name.rawValue)
        }

        /*
        // for APNs token
        NotificationCenter.default.addObserver(forName: PushManagerConstants.PushTokenUpdated, object: nil, queue: nil) {
            print(n)
        }
         */
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
                // print("localizedDescription", error?.localizedDescription ?? "")
                // print("localizedFailureReason", error?.localizedFailureReason ?? "")
                // print("localizedRecoveryOptions", error?.localizedRecoveryOptions ?? "")
                print("localizedRecoverySuggestion", error?.localizedRecoverySuggestion ?? "")
                self.displayError(message:  error?.localizedFailureReason ?? "Login failed")
                return
            }
            
            // we have valid session
            precondition(Session.sharedInstance.currentUser != nil, "User is not logged in?")
            
            self.enableContexts()
            self.registerForPushStatus()
            self.enablePush()
            self.performSegue(withIdentifier: "display_zones", sender: self)
        }
    }

    private func logoutFinished() {
        precondition(Session.sharedInstance.currentUser == nil, "User is logged out, but has a 'currentUser' set")
        self.disableContexts()
        self.disablePush()
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
