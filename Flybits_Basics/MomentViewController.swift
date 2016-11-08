//
//  MomentViewController.swift
//  Flybits_Basics
//
//  Created by Archuthan Vijayaratnam on 2016-11-06.
//  Copyright © 2016 Flybits. All rights reserved.
//

import UIKit
import FlybitsSDK

class MomentViewController: UITableViewController {
    var moments: [Moment] = []
    var momentRequest: FlybitsRequest?
    var zoneId: String!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        getMoments()
        
        do {
            // register for different push topics to listn
            let connected = PushManagerConstants.PushConnected
            let modified = PushMessage.NotificationType(.zone, action: .momentModified)
            let removed = PushMessage.NotificationType(.zone, action: .momentDeleted)
            let momentInstanceModified = PushMessage.NotificationType(.momentInstance, action: .modified)
            
            // when FlybitsSDK receives push message, it will post those notification... and the closure passed in here will be 
            // called for different topics we register.
            NotificationCenter.default.addObserver(forNames: modified, removed, momentInstanceModified) { [weak self] (n) in
                // get the PushMessage from userInfo
                let pushMessage = n.userInfo?[PushManagerConstants.PushMessageContent] as? PushMessage
                
                // find which message called this closure
                switch n.name {
                case connected: // after push is connected, register all the zones for push
                    self?.registerForPush()
                    
                case modified:
                    // get the content that was downloaded, i.e., zone or moment
                    let obj = n.userInfo?[PushManagerConstants.PushFetchedContent] as? [String: AnyObject]
                    // get the moment object
                    let m = obj?[PushMessageEntity.zoneMomentInstance.description] as? Moment
                    // get the zone object
                    let _ = obj?[PushMessageEntity.zone.description] as? Zone
                    
                    // if we have a moment object, then it's not removed!
                    if let m = m {
                        self?.momentModified(moment: m)
                    } else if let identifier = pushMessage?.body?["momentID"] as? String {
                        // we don't have a moment object, but have an ID, that means,
                        // moment is no longer available to us
                        self?.momentRemoved(momentIdentifier: identifier)
                    }
                    
                case momentInstanceModified:
                    // when a name/metadata/image is modified, this gets called,
                    // it doesn't return the actual moment object, instead it returns
                    // an 'momentinstance' id.. using this, we gotta get all the 
                    // moments that has the same 'momentinstance' id and also attached
                    // to a zone
                    if let identifier = pushMessage?.body?["id"] as? String {
                        self?.momentInstanceModified(momentInstanceIdentifier: identifier)
                    }
                    
                case removed:
                    if let identifier = pushMessage?.body?["momentID"] as? String {
                        // we don't have a moment object, but have an ID, that means,
                        // moment is no longer available to us
                        self?.momentRemoved(momentIdentifier: identifier)
                    }
                default: print("Received push but not handling it: ", n.name)
                }
            }
        }
    }
    
    private func momentInstanceModified(momentInstanceIdentifier: String) {
        // Get the top 20 published moments that has the same 'momentinstance' identifier
        // and then check all the moments we have with that instance identifier to replace them
        // Note: Technically, We should get all the moments and not just top 20...
        
        let query = MomentQuery.init(limit: 20, offset: 0)
        query.published = true
        query.momentInstanceIDs = [momentInstanceIdentifier]
        let _ = MomentRequest.query(query) { [weak self] (moments, pagination, error) in
            OperationQueue.main.addOperation {
                for m in moments {
                    self?.momentModified(moment: m)
                }
            }
        }.execute()
    }
    
    private func momentRemoved(momentIdentifier: String) {
        // find the moment that was removed, if the moment is not accessible by current logged in user,
        // we don't get a moment object back, instead only the id.
        // Remove that moment from our list, and then update the view
        
        for m in self.moments.enumerated() where m.element.identifier == momentIdentifier {
            self.moments.remove(at: m.offset)
            self.tableView.deleteRows(at: [IndexPath.init(row: m.offset, section: 0)], with: .automatic)
        }
    }

    private func momentModified(moment: Moment) {
        // We got moment modified push message! This message is triggered when a moment gets published or unpublished.
        // We should check the publish status, if its still published, then update the old moment with new moment object
        // if it's unpublished, then remove it from our list
        // if we don't have this moment and it is published, then add it to our list of moments
        
        var found = false // do we have this moment in our list
        for m in self.moments.enumerated() where m.element.identifier == moment.identifier {
            found = true
            if !moment.published {
                self.moments.remove(at: m.offset)
                self.tableView.deleteRows(at: [IndexPath.init(row: m.offset, section: 0)], with: .automatic)
            } else {
                self.moments[m.offset] = moment
                self.tableView.reloadRows(at: [IndexPath.init(row: m.offset, section: 0)], with: .automatic)
            }
        }
        
        // we don't have this moment and it is published, so add it to end of our list
        if !found && moment.published {
            self.moments.append(moment)
            self.tableView.insertRows(at: [IndexPath.init(row: moments.count - 1, section: 0)], with: .automatic)
        }
    }
    
    private func getMoments() {
        // query the server for 20 moments
        let query = MomentQuery.init()
        query.pager = Pager.init(limit: 20, offset: 0, countRecords: nil)
        query.zoneIDs = [zoneId]
        query.published = true
        
        // cancel any previous request
        _ = momentRequest?.cancel()
        momentRequest = MomentRequest.query(query) { [weak self] (moments, pager, error) in
            OperationQueue.main.addOperation {
                self?.moments = moments
                self?.registerForPush()
                self?.tableView.reloadData()
            }
        }.execute()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let id = segue.identifier, id == "display_aob",
            let cell = sender as? UITableViewCell,
            let index = tableView.indexPath(for: cell) {
            
            let item = moments[index.row]
            let mVC = segue.destination as? AOBMomentViewController
            mVC?.moment = item
        }
    }


    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return moments.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let m = moments[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "moment_cell", for: indexPath)
        cell.textLabel?.text = m.name.value
        cell.detailTextLabel?.text = m.packageName
        cell.imageView?.image = #imageLiteral(resourceName: "ic_default_zone")
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let m = moments[indexPath.row]
        cell.imageView?.image = #imageLiteral(resourceName: "ic_default_zone")
        guard  let image = m.image else {
            print("Moment does not have an image")
            return
        }
        _ = ImageRequest.download(image, nil, ._20) { (image, error) in
            OperationQueue.main.addOperation {
                let c = cell
                c.imageView!.image = image
            }
        }.execute()
    }
    
    //MARK: Handle Zone changes Push messages
    private func registerForPush() {
        for m in moments {
            m.subscribeToPush()
        }
    }
}
