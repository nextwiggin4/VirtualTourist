//
//  Pin.swift
//  VirtualTourist
//
//  Created by Matthew Dean Furlo on 7/23/15.
//  Copyright (c) 2015 FurloBros. All rights reserved.
//

import UIKit
import CoreData
import MapKit

@objc(Pin)

class Pin : NSManagedObject {
    
    
    // store the latitude, longitude of the Pin's location to be persisted
    @NSManaged var latitude: NSNumber!
    @NSManaged var longitude: NSNumber!
    @NSManaged var pictures: [Picture]
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    // initialize the pin based on the longitude and latitude supplied at the 2D Coordinate.
    init(location: CLLocationCoordinate2D, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        latitude = location.latitude
        longitude = location.longitude
    }

}
