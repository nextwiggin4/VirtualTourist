//
//  flickr.swift
//  VirtualTourist
//
//  Created by Matthew Dean Furlo on 7/22/15.
//  Copyright (c) 2015 FurloBros. All rights reserved.
//

import Foundation

class flickr : NSObject {
    
    typealias CompletionHander = (result: AnyObject!, error: NSError?) -> Void
    
    var session: NSURLSession
    
    override init(){
        session = NSURLSession.sharedSession()
        super.init()
    }
    
    
    // MATTHEW: - All purpose task method for data
    
    /* Function makes first request to get the total number of possible pages, then picks a random page. It then makes a request to get the images on the random page */
    func getImagesFromFlickrBySearch(methodArguments: [String : AnyObject], completionHandler: CompletionHander) -> NSURLSessionDataTask {
        
        let session = NSURLSession.sharedSession()
        let urlString = flickr.Constants.BaseURL + flickr.escapedParameters(methodArguments)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            if let error = downloadError {
                println("Could not complete the request \(error)")
            } else {
                
                var parsingError: NSError? = nil
                let parsedResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parsingError) as! NSDictionary
                
                if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
                    
                    if let totalPages = photosDictionary["pages"] as? Int {
                        
                        /* Flickr API - will only return up the 4000 images (18 per page * 222 page max) */
                        let pageLimit = min(totalPages, (4000/flickr.Resources.PER_PAGE.toInt()!))
                        let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
                        self.getImagesFromFlickrBySearchWithPage(methodArguments, pageNumber: randomPage, completionHandler: completionHandler)
                        
                    } else {
                        println("Cant find key 'pages' in \(photosDictionary)")
                    }
                } else {
                    println("Cant find key 'photos' in \(parsedResult)")
                }
            }
        }
        
        task.resume()
        
        return task
    }
    
    /* This function retrieves the randomly selected page of photos and returns the parsed object containing all the photos url */
    func getImagesFromFlickrBySearchWithPage(methodArguments: [String : AnyObject], pageNumber: Int, completionHandler: CompletionHander) {
        
        /* Add the page to the method's arguments */
        var withPageDictionary = methodArguments
        withPageDictionary["page"] = pageNumber
        
        let session = NSURLSession.sharedSession()
        let urlString = flickr.Constants.BaseURL + flickr.escapedParameters(withPageDictionary)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            if let error = downloadError {
                let newError = flickr.errorForData(data, response: response, error: error)
                completionHandler(result: nil, error: downloadError)
            } else {
                flickr.parseJSONWithCompletionHandler(data, completionHandler: completionHandler)
            }
        }
        
        task.resume()
    }
    
    // MATTHEW: - All purpose task method for images
    
    /* this function will download the pictures from Flickr at the specified URL */
    func taskForImage(filePath: String, completionHandler: (imageData: NSData?, error: NSError?) ->  Void) -> NSURLSessionTask {
        
        
        let baseURL = NSURL(string: filePath)!
        let url = baseURL
        
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            
            if let error = downloadError {
                let newError = flickr.errorForData(data, response: response, error: downloadError)
                completionHandler(imageData: nil, error: newError)
            } else {
                completionHandler(imageData: data, error: nil)
            }
        }
        
        task.resume()
        
        return task
    }
    
    // MATTHEW: - Helpers
    
    
    // Try to make a better error, based on the status_message from flickr. If we cant then return the previous error
    
    class func errorForData(data: NSData?, response: NSURLResponse?, error: NSError) -> NSError {
        
        if let parsedResult = NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments, error: nil) as? [String : AnyObject] {
            if let errorMessage = parsedResult[flickr.Keys.ErrorStatusMessage] as? String {
                
                let userInfo = [NSLocalizedDescriptionKey : errorMessage]
                
                return NSError(domain: "flickr Error", code: 1, userInfo: userInfo)
            }
        }
        
        return error
    }
    
    // Parsing the JSON
    
    class func parseJSONWithCompletionHandler(data: NSData, completionHandler: CompletionHander) {
        var parsingError: NSError? = nil
        
        let parsedResult: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parsingError)
        
        if let error = parsingError {
            completionHandler(result: nil, error: error)
        } else {
            completionHandler(result: parsedResult, error: nil)
        }
    }
    
    // URL Encoding a dictionary into a parameter string
    
    class func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            // Make sure that it is a string value
            let stringValue = "\(value)"
            
            // Escape it
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            // Append it
            
            urlVars += [key + "=" + "\(escapedValue!)"]
        }
        
        return (!urlVars.isEmpty ? "?" : "") + join("&", urlVars)
    }
    
    
    // MATTHEW: - Shared Instance
    
    class func sharedInstance() -> flickr {
        
        struct Singleton {
            static var sharedInstance = flickr()
        }
        
        return Singleton.sharedInstance
    }
    
    // MATTHEW: - Shared Date Formatter
    
    class var sharedDateFormatter: NSDateFormatter  {
        
        struct Singleton {
            static let dateFormatter = Singleton.generateDateFormatter()
            
            static func generateDateFormatter() -> NSDateFormatter {
                var formatter = NSDateFormatter()
                formatter.dateFormat = "yyyy-mm-dd"
                
                return formatter
            }
        }
        
        return Singleton.dateFormatter
    }
    
    // MATTHEW: - Shared Image Cache
    
    struct Caches {
        static let imageCache = ImageCache()
    }
    
    func createBoundingBoxString(longitude: Double, latitude: Double) -> String {
        
        /* Fix added to ensure box is bounded by minimum and maximums */
        let bottom_left_lon = max(longitude - flickr.Resources.BOUNDING_BOX_HALF_WIDTH, flickr.Resources.LON_MIN)
        let bottom_left_lat = max(latitude - flickr.Resources.BOUNDING_BOX_HALF_HEIGHT, flickr.Resources.LAT_MIN)
        let top_right_lon = min(longitude + flickr.Resources.BOUNDING_BOX_HALF_HEIGHT, flickr.Resources.LON_MAX)
        let top_right_lat = min(latitude + flickr.Resources.BOUNDING_BOX_HALF_HEIGHT, flickr.Resources.LAT_MAX)
        
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }

    
}