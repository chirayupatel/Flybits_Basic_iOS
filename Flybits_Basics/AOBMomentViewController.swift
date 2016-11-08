//
//  AOBMomentViewController.swift
//  Flybits_Basics
//
//  Created by Archuthan Vijayaratnam on 2016-11-07.
//  Copyright © 2016 Flybits. All rights reserved.
//

import UIKit
import FlybitsSDK

class AOBMomentViewController: UIViewController {
    // display the result in a textview
    @IBOutlet var textView: UITextView!

    // AOB moment
    var moment: Moment!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // check if it's AOB moment, otherwise display 'error'
        if let moment = moment, moment.packageName == "com.flybits.moments.jsonbuilder" {
            textView.text = ""
            
            // go and fetch the data from AOB moment
            getData()
        } else {
            textView.text = "Not an AOB moment"
        }
    }
    
    private func getData() {
        // validation should happen before accessing the content of a moment...
        // i.e., does the current user has enough permission to access the content?
        _ = MomentRequest.autoValidate(moment: moment) { (success, error) in
            if success { // validation succeeded
                
                // get the content of this specific moment... and serialize the content to Users class
                _ = AOBRequest.getData(moment: self.moment, template: Users.self) { (data, error) in
                    print(data, error)
                    OperationQueue.main.addOperation {
                        // display the moment's data inside a textview
                        if let error = error {
                            self.textView.text = error.description
                        } else {
                            self.textView.text = data?.description
                        }
                    }
                }
            } else { // validation failed
                print(error)
            }
        }.execute()
    }
}


/**
 A container class for profile items. AOBRequest uses this class to serialize returned data into this class. Note, for this class to work, your AOB moment has to have this as the data type:
 
{
   "users": [
     {
         "firstname": "Jane"
     },
     {
        "firstname": "John"
     }
   ]
}
 */
class Users : Parsable, AOBContentType, CustomStringConvertible {
    var users: [Profile] = [Profile]()
    
    required init?(data: Any) {
        guard let d = data as? [String: [AnyObject]] else {
            print("Expected dictionary")
            return nil
        }
        users = try! d.jsonObject("users", [Profile].self)
    }
    
    var description: String {
        let items = users.map({ $0.description })
        return items.joined(separator: "\n")
    }
}

/*
    A user profile class
 
    Parses out firstname, lastname and address from AOB data
 */
class Profile: Parsable, AOBContentType, CustomStringConvertible {
    var firstname: String
    var lastname: String?
    var address: String?
    
    required init?(data: Any) {
        
        guard let d = data as? [String: AnyObject] else {
            print("Expected dictionary")
            return nil
        }
        
        firstname = d.jsonObject("firstname") ?? "n/a"
        lastname = d.jsonObject("lastname")
        address = d.jsonObject("address")
    }
    
    var description: String {
        return "firstname: \(firstname)"
    }
}
