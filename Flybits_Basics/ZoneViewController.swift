//
//  ZoneViewController.swift
//  Flybits_Basics
//
//  Created by Archuthan Vijayaratnam on 2016-11-06.
//  Copyright © 2016 Flybits. All rights reserved.
//

import UIKit
import FlybitsSDK

class ZoneViewController: UITableViewController {
    var zones: [Zone] = []
    var zoneRequest: FlybitsRequest?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        getZones()
        
        let modified = PushMessage.NotificationType(.zone, action: .modified)
        let removed = PushMessage.NotificationType(.zone, action: .deleted)
        NotificationCenter.default.addObserver(forNames: PushManagerConstants.PushConnected) { [weak self] n in
            switch n.name {
            case PushManagerConstants.PushConnected:
                // after push is connected, register all the zones for push
                self?.registerForPush()
                
            case modified:
                print(n)
                // let m = n.userInfo?[PushManagerConstants.PushMessageContent] as? PushMessage
                if let z = n.userInfo?[PushManagerConstants.PushFetchedContent] as? Zone {
                    self?.zoneReceivedPush(zone: z)
                } else if let e = n.userInfo?[PushManagerConstants.PushFetchError] as? NSError {
                    if let m = n.userInfo?[PushManagerConstants.PushMessageContent] as? PushMessage, let zoneId = m.body?["id"] as? String, e.code == 404 {
                        self?.zoneRemoved(zoneIdentifier: zoneId)
                    }
                }
            case removed:
                // when a zone is removed.. note that unpublishing a zone is not same as removing it...
                if let m = n.userInfo?[PushManagerConstants.PushMessageContent] as? PushMessage, let zoneId = m.body?["id"] as? String {
                    self?.zoneRemoved(zoneIdentifier: zoneId)
                }
            default: print("Received push but not handling it: ", n.name)
            }
        }
    }
    
    private func zoneRemoved(zoneIdentifier: String) {
        // when a zone is removed, we only get their ID, so remove the zone from our list of zones
        // and then update the UI
        for z in self.zones.enumerated() where z.element.identifier == zoneIdentifier {
            self.zones.remove(at: z.offset)
            self.tableView.deleteRows(at: [IndexPath.init(row: z.offset, section: 0)], with: .automatic)
        }
    }
    
    private func zoneReceivedPush(zone: Zone) {
        var found = false
        for z in self.zones.enumerated() where z.element.identifier == zone.identifier {
            found = true
            if !zone.published {
                self.zones.remove(at: z.offset)
                self.tableView.deleteRows(at: [IndexPath.init(row: z.offset, section: 0)], with: .automatic)
            } else {
                self.zones[z.offset] = zone
                self.tableView.reloadRows(at: [IndexPath.init(row: z.offset, section: 0)], with: .automatic)
            }
        }
        if !found && zone.published {
            self.zones.append(zone)
            self.tableView.insertRows(at: [IndexPath.init(row: zones.count - 1, section: 0)], with: .automatic)
        }
    }
    
    private func getZones() {
        let zoneQuery = ZonesQuery.init()
        zoneQuery.pager = Pager.init(limit: 20, offset: 0, countRecords: nil)
        zoneQuery.zoneIDs = ["1BC7E116-7BBE-4856-AD48-BC932311F529"]
        // z.favourites = true
        // z.tagIDs = ["TAGID1"]
        
        _ = zoneRequest?.cancel()
        zoneRequest = ZoneRequest.query(zoneQuery) { [weak self] (zones, pager, error) in
            OperationQueue.main.addOperation {
                self?.zones = zones
                self?.registerForPush()
                self?.tableView.reloadData()
            }
            
        }.execute()
        
    }
    
    //MARK: Tableview
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return zones.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let z = zones[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "zone_cell", for: indexPath)
        cell.textLabel?.text = z.name.value
        cell.detailTextLabel?.text = z.zoneDescription.value
        cell.imageView?.image = #imageLiteral(resourceName: "ic_default_zone")
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let z = zones[indexPath.row]
        cell.imageView?.image = #imageLiteral(resourceName: "ic_default_zone")
        _ = ImageRequest.download(z.image, nil, ._20) { (image, error) in
            OperationQueue.main.addOperation {
                let c = cell
                c.imageView!.image = image
            }
        }.execute()
    }
    
    //MARK: Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let id = segue.identifier, id == "display_moments",
            let cell = sender as? UITableViewCell,
            let index = tableView.indexPath(for: cell) {
            
            let item = zones[index.row]
            let mVC = segue.destination as? MomentViewController
            mVC?.zoneId = item.identifier
        }
    }
    
    //MARK: Handle Zone changes Push messages
    private func registerForPush() {
        for z in zones {
            z.subscribeToPush()
        }
    }
    
}

