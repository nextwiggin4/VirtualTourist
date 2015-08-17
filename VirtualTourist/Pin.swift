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
    
    
    struct Keys {
        static let Latitude = "latitude"
        static let Longitude = "longitude"
    }
    
    @NSManaged var latitude: NSNumber!
    @NSManaged var longitude: NSNumber!
    @NSManaged var pictures: [Picture]
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(location: CLLocationCoordinate2D, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        latitude = location.latitude
        longitude = location.longitude
    }
   /*
    var annotation: MKPointAnnotation {
        var newPoint = MKPointAnnotation()
        newPoint.coordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(latitude), longitude: CLLocationDegrees(longitude))
        return newPoint
    }
    */
}
