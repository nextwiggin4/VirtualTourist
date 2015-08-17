//
//  flickrConstants.swift
//  VirtualTourist
//
//  Created by Matthew Dean Furlo on 7/22/15.
//  Copyright (c) 2015 FurloBros. All rights reserved.
//

import Foundation

extension flickr {
    struct Constants {
        static let ApiKey = "2ff7aac0a5ad59e8b525b63af1c06be8"
        static let BaseURL = "https://api.flickr.com/services/rest/"
    }
    
    struct Resources {
        static let METHOD_NAME = "flickr.photos.search"
        static let EXTRAS = "url_m"
        static let SAFE_SEARCH = "1"
        static let DATA_FORMAT = "json"
        static let NO_JSON_CALLBACK = "1"
        static let BOUNDING_BOX_HALF_WIDTH = 1.0
        static let BOUNDING_BOX_HALF_HEIGHT = 1.0
        static let LAT_MIN = -90.0
        static let LAT_MAX = 90.0
        static let LON_MIN = -180.0
        static let LON_MAX = 180.0
        static let PER_PAGE = "18"
    }
    
    struct Keys {
        static let ID = "id"
        static let ErrorStatusMessage = "status_message"
    }
}