//
//  TrackListViewController.swift
//  ShipShape
//
//  Created by Sam Kronick on 5/26/16.
//  Copyright © 2016 Disk Cactus. All rights reserved.
//

import Foundation
import UIKit

class TrackListViewController : UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var trackTableView: UITableView!
    
    
    // Retreive the managedObjectContext from AppDelegate
    let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
    let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
    
    // An array to hold track objects
    var tracks = [Path]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //self.trackTableView.registerClass(UITableViewCell.classForCoder(), forCellReuseIdentifier: "PathCell")
        self.trackTableView.dataSource = self
        
        if Sailor.ActiveSailor != nil {
            self.tracks = Path.FetchPathsForSailorInContext(self.managedObjectContext, sailor: Sailor.ActiveSailor!)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        
    }
    
    
    // MARK: - UITableViewDelegate
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tracks.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("PathCell")! as UITableViewCell
        //let cell = UITableViewCell(style:  , reuseIdentifier: "PathCell")
        
        let titleLabel = cell.viewWithTag(100) as! UILabel
        let dateLabel = cell.viewWithTag(101) as! UILabel
        let statsLabel = cell.viewWithTag(102) as! UILabel
        
        
        let path = self.tracks[indexPath.row]
        path.recalculateStats()
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateStyle = .MediumStyle
        dateFormatter.timeStyle = .ShortStyle
        
        
        let nf = NSNumberFormatter()
        nf.numberStyle = NSNumberFormatterStyle.DecimalStyle
        nf.maximumFractionDigits = 2
        
        //let time = nf.stringFromNumber(path.totalTime! as Double / 60.0)!
        let (hours, minutes) = NSNumber.toHoursMinutes(path.totalTime!)
        let minutesNF = NSNumberFormatter()
        minutesNF.minimumIntegerDigits = 2
    
        let minutesString = nf.stringFromNumber(minutes)
        
        let distance = nf.stringFromNumber(metersToNauticalMiles(path.totalDistance!))!
        let speed = nf.stringFromNumber(metersPerSecondToKnots(path.averageSpeed!))!
        
        let dateString = path.created != nil ? dateFormatter.stringFromDate(path.created!) : "(UNKNOWN)"
        
        titleLabel.text = path.title == nil || path.title! == "" ? "Unnamed Track" : path.title!
        dateLabel.text = "\(dateString)"
        statsLabel.text = "\(distance) NM | \(hours):\(minutesString!) hrs | \(speed) kts"
        
        return cell
    }
    
}