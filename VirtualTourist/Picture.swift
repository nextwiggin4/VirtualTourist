//
//  Picture.swift
//  VirtualTourist
//
//  Created by Matthew Dean Furlo on 7/23/15.
//  Copyright (c) 2015 FurloBros. All rights reserved.
//

import UIKit
import CoreData

@objc(Picture)

class Picture : NSManagedObject {
    struct Keys {
        static let PicturePath = "url_m"
        static let Title = "title"
        static let Height = "height_m"
        static let Width = "width_m"
    }
    
    @NSManaged var title: String
    @NSManaged var picturePath: String
    @NSManaged var height: NSNumber
    @NSManaged var width: NSNumber
    @NSManaged var pin: Pin?
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Picture", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        title = dictionary[Keys.Title] as! String
        picturePath = dictionary[Keys.PicturePath] as! String
        var mutableHeight = dictionary[Keys.Height] as! String
        height = mutableHeight.toInt()!
        var mutableWidth = dictionary[Keys.Width] as! String
        width = mutableWidth.toInt()!
    }
    
    var pictureImage: UIImage? {
        
        get{
            return flickr.Caches.imageCache.imageWithIdentifier(picturePath)
        }
        
        set{
            flickr.Caches.imageCache.storeImage(newValue, withIdentifier: picturePath)
        }
    }
}
