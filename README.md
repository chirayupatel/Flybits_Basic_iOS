#Flybits Basics for iOS#

####Downloads:####
_Note: This code is built with FlybitsSDK 3.3.0_

This project demonstrates basic functionality of using Flybits such as to register or login, to get zones & moments, and to register and receive push messages.

##User management##

`LoginViewController` displays a login page where user can enter their email and password to login or they can anonymously login. Anonymous login creates a temp email and password and stores it inside NSUserDefaults, and uses that to login.

Logout button is also available, tapping on it makes a logout request to server.

After user is successfully logged in, few things are enabled:

- context uploading
- push message

####1. Context Uploading:####

Few context plugins are registered with default settings:
	
```
let fiveMins = 5 * 60
    
let cm = ContextManager.sharedManager
_ = cm.register(.activity, priority: .any, pollFrequency: fiveMins, uploadFrequency: fiveMins)
_ = cm.register(.audio, priority: .any, pollFrequency: fiveMins, uploadFrequency: fiveMins)
_ = cm.register(.availability, priority: .any, pollFrequency: fiveMins, uploadFrequency: fiveMins)
_ = cm.register(.battery, priority: .any, pollFrequency: fiveMins, uploadFrequency: fiveMins)
_ = cm.register(.coreLocation, priority: .any, pollFrequency: fiveMins, uploadFrequency: fiveMins)
```


iBeacon plugin is registered with custom settings:

```
do {   // enable iBeacon context provider
    let coreLoc = CoreLocationDataProvider.init(asCoreLocationManager: true, withRequiredAuthorization: .authorizedAlways)
    _ = try? coreLoc.requestAlwaysAuthorization()
    
    let options = Set<iBeaconDataProvider.iBeaconOptions>.init(arrayLiteral: .monitoring, .ranging)
    let ibeacon = iBeaconDataProvider.init(apiFrequency: fiveMins, locationProvider: coreLoc, options: options)
    ibeacon.startBeaconQuery()
    
    _ = try? cm.register(ibeacon)
    
    ibeaconContextDataProvider = ibeacon
}
```

After everythign is registered, start the context monitoring and uploading:

```
cm.startDataPolling()

```


####2. Registering for Push Message:####

PushManager posts notification everytime it's status changes with Flybits Push server. Those can be listened by the apps as well:

Connected and Disconnected can be listened to update the UI or change the logic on your app, maybe switch to Polling if push is disconnected.

```
// register for push status
NotificationCenter.default.addObserver(forName: PushManagerConstants.PushConnected, object: nil, queue: nil) { n in
    print(n.name.rawValue)
}
    
NotificationCenter.default.addObserver(forName: PushManagerConstants.PushDisconnected, object: nil, queue: nil) { n in
    print(n.name.rawValue)
}
```


To setup the FlybitsSDK so it can start receiving push messages, you have to enable the PushManager with a PushConfiguration.

To listen to entity related changes such as Zone modified, Moment modified, etc., enable 'foreground' push service type.

`        PushManager.sharedManager.configuration = PushConfiguration.configuration(with: .foreground)
`

Use `.both` if you are also supporting APNs as well. Remember to set the `apnsToken` after user successfully logs in so it can be uploaded to Flybits servers.



##Zones##

####Getting list of Zones###
`ZoneViewController` queries the server and displays list of Zones in a UITableView. Setup a `ZoneQuery` object and then execute that query using `ZoneRequest`.

This example shows how to get first 20 zones that are favourited by currently logged in user.

```
let zoneQuery = ZonesQuery.init()
zoneQuery.pager = Pager.init(limit: 20, offset: 0, countRecords: nil)
zoneQuery.pager.favourites = true
    
ZoneRequest.query(zoneQuery) { [weak self] (zones, pager, error) in
	print(zones)    
}.execute()
```


####Zone related Push####
Subscribe each zone entities for push message:

```
private func registerForPush() {
    for z in zones {
        z.subscribeToPush()
    }
}
```

and then using a custom extension on NotificationCenter, listen to few different topics so we can act upon receiving a push:

```

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

```

##Moments##

####Getting list of Moments###
`MomentViewController` queries the server for all the moments inside a zone and displays list of Moments in a UITableView. Setup a `MomentQuery` object and then execute that query using `MomentRequest`.

This example shows how to get first 20 moemnts inside a zone.

```
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

```


####Moment related Push####
Subscribe each moment entities for push message:

```
private func registerForPush() {
    for m in moments {
        m.subscribeToPush()
    }
}
```

and then using a custom extension on NotificationCenter, listen to few different topics so we can act upon receiving a push:

```

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

```

