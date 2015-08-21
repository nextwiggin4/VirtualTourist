//
//  ImageCache.swift
//  VirtualTourist
//
//  Created by Matthew Dean Furlo on 7/22/15.
//  Copyright (c) 2015 FurloBros. All rights reserved.
//

import UIKit

class ImageCache {
    /* this class is used to create a temporary image cahce. The app will download the images from flickr and store them in a cache until this system needs to free up memory. Then the images will be deleted and redownloaded if they are needed again. This will prevent the harddrive from quickly filling up as a multitude of pins are added. This also simplifies the deletion process, since the images will automatically deleted after long periods of non-use  */
    
    private var inMemoryCache = NSCache()
    
    
    //this function determines if there is an image in the cache at the stored path. If it is stored it returns the image, otherwise it returns nil
    func imageWithIdentifier(identfier: String?) ->UIImage? {
        if identfier == nil || identfier! == ""{
            return nil
        }
        
        let path = pathForIdentifier(identfier!)
        var data: NSData?
        
        if let image = inMemoryCache.objectForKey(path) as? UIImage {
            return image
        }
        
        if let data = NSData(contentsOfFile: path) {
            return UIImage(data: data)
        }
        
        return nil
    }
    
    //this function will create a cache of a provided image at the specified identifier path.
    func storeImage(image: UIImage?, withIdentifier identifier: String) {
        let path = pathForIdentifier(identifier)
        
        
        inMemoryCache.setObject(image!, forKey: path)
        
        let data = UIImagePNGRepresentation(image!)
        data.writeToFile(path, atomically: true)
    }
    
    func removeImage(identifier: String) {
        let path = pathForIdentifier(identifier)
        
        //this removes the object saved at the key value
        inMemoryCache.removeObjectForKey(path)
        println("call to remove item at path")

        
    }
    
    //this function is a simple helper method that converts the image identifier to the path that it would be stored on the harddrive.
    func pathForIdentifier(identifier: String) -> String {
        let documentsDirectoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first as! NSURL
        let fullURL = documentsDirectoryURL.URLByAppendingPathComponent(identifier)
        
        return fullURL.path!
    }
        
    
}
