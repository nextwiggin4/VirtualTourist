//
//  PictureCell.swift
//  VirtualTourist
//
//  Created by Matthew Dean Furlo on 7/30/15.
//  Copyright (c) 2015 FurloBros. All rights reserved.
//

import UIKit

class PictureCell: UICollectionViewCell {
    
    @IBOutlet weak var flickrPictureView: UIImageView!
    @IBOutlet weak var downloadIndicator: UIActivityIndicatorView!
    
    //this will let you set the UIImage of the cells, but if there is no image (it's nil) it'll return the posterPlaceHolder image instead.
    var flickrPicture: UIImage {
        set {
            self.flickrPictureView.image = newValue
        }
        
        get {
            return self.flickrPictureView.image ?? UIImage(named: "posterPlaceHolder")!
        }
    }
    
}
