//
//  ImageCache.swift
//  VirtualTourist
//
//  Created by Matthew Dean Furlo on 7/22/15.
//  Copyright (c) 2015 FurloBros. All rights reserved.
//

import UIKit

class ImageCache {
    private var inMemoryCache = NSCache()
    
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
    
    func storeImage(image: UIImage?, withIdentifier identifier: String) {
        let path = pathForIdentifier(identifier)
        
        if image == nil{
            inMemoryCache.removeObjectForKey(path)
            NSFileManager.defaultManager().removeItemAtPath(path, error: nil)
            return
        }
        
        inMemoryCache.setObject(image!, forKey: path)
        
        let data = UIImagePNGRepresentation(image!)
        data.writeToFile(path, atomically: true)
    }
    
    func pathForIdentifier(identifier: String) -> String {
        let documentsDirectoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first as! NSURL
        let fullURL = documentsDirectoryURL.URLByAppendingPathComponent(identifier)
        
        return fullURL.path!
    }
        
    
}
