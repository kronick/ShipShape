//
//  AppDelegate.swift
//  ShipShape
//
//  Created by Sam Kronick on 5/21/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import UIKit
import CoreData
import CoreLocation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var locationTrackerManager = LocationTrackerManager.sharedInstance

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        
        
        // Force the logged in username to "anonymous"
        
        let defaultUsername = "anonymous"
        
        // See if there is a username saved and use it if so
        var currentUsername = defaultUsername
        var currentPassword = ""
        if let savedUsername = NSUserDefaults.standardUserDefaults().objectForKey("loggedInUsername") as? String  {
            currentUsername = savedUsername
        }
        if let savedPassword = NSUserDefaults.standardUserDefaults().objectForKey("loggedInPassword") as? String  {
            currentPassword = savedPassword
        }
        
        logIn(currentUsername, password: currentPassword)
        
        locationTrackerManager.initialize()
        
        return true
    }
    
    func logIn(username: String, password: String) {
        // Keep track of the old Sailor logged in 
        // If the username is "anonymous" all that Sailor's tracks will be moved to the new user
        let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
        var oldSailor: Sailor?
        if let oldUsername = NSUserDefaults.standardUserDefaults().objectForKey("loggedInUsername") as? String {
            oldSailor = Sailor.FetchByUsernameInContext(self.managedObjectContext, username: oldUsername)
        }
        
        
        // Set NSUserDefaults
        NSUserDefaults.standardUserDefaults().setObject(username, forKey: "loggedInUsername")
        NSUserDefaults.standardUserDefaults().setObject(password, forKey: "loggedInPassword")
        
        let defaultVesselName = "anonymous ship"
        
        // Make make sure sure a Sailor and Vessel managed object exists for that username, create if not
        // First fetch looking for a Sailor with that username
        let sailorResult = Sailor.FetchByUsernameInContext(self.managedObjectContext, username: username)
        if sailorResult != nil {
            Sailor.ActiveSailor = sailorResult
        }
        else {
            Sailor.ActiveSailor = Sailor.CreateInContext(self.managedObjectContext, username: username, realName: "Local User")
        }
        
        // Now make sure the current sailor has a vessel
        let vesselResults = Vessel.FetchByOwnerInContext(self.managedObjectContext, owner: Sailor.ActiveSailor!)
        
        if vesselResults.count == 0 {
            Vessel.ActiveVessel = Vessel.CreateInContext(self.managedObjectContext, name: defaultVesselName, owner: Sailor.ActiveSailor)
        }
        else {
            Vessel.ActiveVessel = vesselResults[0]
        }
        
        // Set username and password in RemoteAPIManager
        RemoteAPIManager.sharedInstance.username = username
        RemoteAPIManager.sharedInstance.password = password
        
        // If the previous user was not logged in, copy all their paths to this new user
        if Sailor.ActiveSailor != nil && oldSailor?.username == "anonymous" {
            print("Moving old sailor's paths to new Sailor")
            let oldPaths = Path.FetchPathsForSailorInContext(self.managedObjectContext, sailor: oldSailor!)
            for path in oldPaths {
                path.creator = Sailor.ActiveSailor
            }
        }
        
        do {
            try managedObjectContext.save()
        }
        catch let error as NSError {
            print("Could not save data \(error), \(error.userInfo)")
        }
        
        print("Current Sailor: \(Sailor.ActiveSailor?.username)\nCurrent Vessel: \(Vessel.ActiveVessel?.name)")
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }

    // MARK: - Core Data stack

    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.diskcactus.ShipShape" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("ShipShape", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("SingleViewCoreData.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        let options: [NSObject:AnyObject] = [NSMigratePersistentStoresAutomaticallyOption: 1, NSInferMappingModelAutomaticallyOption: 1]
        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: options)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason

            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
    }()

    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }

    
    
}

