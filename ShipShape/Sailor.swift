//
//  Sailor.swift
//  ShipShape
//
//  Created by Sam Kronick on 5/22/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import Foundation
import CoreData


class Sailor: NSManagedObject {
    static var ActiveSailor: Sailor?
    
    class func CreateInContext(moc: NSManagedObjectContext, username: String, realName: String? = nil, profile: String? = nil) -> Sailor {
        let newSailor = NSEntityDescription.insertNewObjectForEntityForName("Sailor", inManagedObjectContext: moc) as! Sailor
        newSailor.username = username
        newSailor.realName = realName
        newSailor.profile = profile
        
        return newSailor
    }
    
    class func FetchByUsernameInContext(moc: NSManagedObjectContext, username: String) -> Sailor? {
        let sailorFetchRequest = NSFetchRequest(entityName: "Sailor")
        sailorFetchRequest.predicate = NSPredicate(format: "username == %@", argumentArray: [username])
        
        do {
            let sailorResults = try moc.executeFetchRequest(sailorFetchRequest) as! [Sailor]
            if sailorResults.count > 0 {
                return sailorResults[0]
            }
            else {
                return nil
            }
        }
        catch let error as NSError {
            print("Could not fetch Sailor \(error), \(error.userInfo)")
        }
        
        return nil
    }
}
