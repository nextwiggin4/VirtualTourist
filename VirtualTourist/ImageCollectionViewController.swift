//
//  ImageCollectionViewController.swift
//  VirtualTourist
//
//  Created by Matthew Dean Furlo on 7/27/15.
//  Copyright (c) 2015 FurloBros. All rights reserved.
//

import Foundation
import CoreData
import MapKit

class ImageCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, NSFetchedResultsControllerDelegate {
    
    var selectedIndexes = [NSIndexPath]()
    
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    @IBOutlet weak var collectionView:UICollectionView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var bottomButton: UIBarButtonItem!
    
    var cancelButton: UIBarButtonItem!
    
    var selectedPin: Pin!
    
    var sharedContext = CoreDataStackManager.sharedInstance().managedObjectContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setMapView()
        
        var error: NSError?
        fetchedResultsController.performFetch(&error)
        
        if let error = error {
            println("Error performing initial fetch: \(error)")
        }
        
        updateBottomButton()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Redo, target: self, action: "reloadView")
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Picture")
        fetchRequest.sortDescriptors = []
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.selectedPin)
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    } ()
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        loadFromFlickr()
    }

    
    func reloadView(){
        var error: NSError?
        fetchedResultsController.performFetch(&error)
        
        if let error = error {
            println("Error performing initial fetch: \(error)")
        }
        
       
        self.collectionView.reloadData()
        

        println("collection reloaded")
    }
    
    func loadFromFlickr() {
        if selectedPin.pictures.isEmpty {
            
            let methodArguments = [
                "method": flickr.Resources.METHOD_NAME,
                "per_page": flickr.Resources.PER_PAGE,
                "api_key": flickr.Constants.ApiKey,
                "safe_search": flickr.Resources.SAFE_SEARCH,
                "extras": flickr.Resources.EXTRAS,
                "format": flickr.Resources.DATA_FORMAT,
                "nojsoncallback": flickr.Resources.NO_JSON_CALLBACK,
                "bbox": flickr.sharedInstance().createBoundingBoxString(selectedPin.longitude.doubleValue, latitude: selectedPin.latitude.doubleValue)
            ]
            
            flickr.sharedInstance().getImagesFromFlickrBySearch(methodArguments){ JSONResults, error in
                if let error = error {
                    println(error)
                } else {
                    if let photos = JSONResults.valueForKey("photos") as? [String: AnyObject] {
                        if let photoDictionaries = photos["photo"] as? [[String :AnyObject]] {
                            
                            
                            var photos = photoDictionaries.map() { (dictionary: [String: AnyObject]) -> Picture in
                                let photo = Picture(dictionary: dictionary, context: self.sharedContext)
                                
                                photo.pin = self.selectedPin
                                
                                return photo
                            }
                            
                            // Save the context
                            self.saveContext()
                            dispatch_async(dispatch_get_main_queue()){
                                var error: NSError?
                                self.fetchedResultsController.performFetch(&error)
                                
                                if let error = error {
                                    println("Error performing initial fetch: \(error)")
                                }
                                
                                println(self.selectedPin.pictures.count)
                            }
              
                        }
                    }
                }
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let layout : UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let width = floor(self.collectionView.frame.size.width/3)
        layout.itemSize = CGSize(width: width, height: width)
        collectionView.collectionViewLayout = layout
    }
    
    func saveContext(){
        CoreDataStackManager.sharedInstance().saveContext()
        println("context has been saved ...probably")
    }

    func configureCell(cell: PictureCell, atIndexPath indexPath: NSIndexPath, picture: Picture) {
        var pictureImage = UIImage(named: "posterPlaceHolder")
        
        cell.flickrPictureView.image = pictureImage
        cell.downloadIndicator.hidden = false
        cell.downloadIndicator.startAnimating()
        
        if picture.pictureImage != nil {
            cell.flickrPictureView.image = picture.pictureImage
            cell.downloadIndicator.stopAnimating()
            cell.downloadIndicator.hidden = true
        } else {
            
            // Start the task that will eventually download the image
            let task = flickr.sharedInstance().taskForImage(picture.picturePath) { data, error in
                
                if let error = error {
                    println("Poster download error: \(error.localizedDescription)")
                }
                
                if let data = data {
                    // Craete the image
                    let image = UIImage(data: data)
                    
                    // update the model, so that the infrmation gets cashed
                    picture.pictureImage = image
                    
                    // update the cell later, on the main thread
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        
                        cell.flickrPictureView.image = image
                        cell.downloadIndicator.stopAnimating()
                        cell.downloadIndicator.hidden = true
                    }
                }
            }
        }
        
        
        if let index = find(selectedIndexes, indexPath) {
            cell.flickrPictureView.alpha = 0.5
        } else {
            cell.flickrPictureView.alpha = 1.0
        }
    }
    
    /*
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }*/
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        
        println("number Of Cells: \(sectionInfo.numberOfObjects)")
        return sectionInfo.numberOfObjects
    }
    
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PictureCell", forIndexPath: indexPath) as! PictureCell
        
        let picture = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Picture
        
        println("a cell has been updated at \(picture.picturePath)")
        
        self.configureCell(cell, atIndexPath: indexPath, picture: picture)
            
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PictureCell
        
        let picture = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Picture
        
        if let index = find(selectedIndexes, indexPath) {
            selectedIndexes.removeAtIndex(index)
        } else {
            selectedIndexes.append(indexPath)
        }
        
        configureCell(cell, atIndexPath: indexPath, picture: picture)
        
        updateBottomButton()
    }
    
    // MARK: - Fetched Results Controller Delegate
    
    // Whenever changes are made to Core Data the following three methods are invoked. This first method is used to create
    // three fresh arrays to record the index paths that will be changed.
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        // We are about to handle some new changes. Start out with empty arrays for each change type
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
        
        //self.collectionView.
        //println("in controllerWillChangeContent")
    }
    
    // The second method may be called multiple times, once for each Color object that is added, deleted, or changed.
    // We store the index paths into the three arrays.
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch type{
            
        case .Insert:
            println("Insert an item")
            // Here we are noting that a new Color instance has been added to Core Data. We remember its index path
            // so that we can add a cell in "controllerDidChangeContent". Note that the "newIndexPath" parameter has
            // the index path that we want in this case
            insertedIndexPaths.append(newIndexPath!)
            break
        case .Delete:
            println("Delete an item")
            // Here we are noting that a Color instance has been deleted from Core Data. We keep remember its index path
            // so that we can remove the corresponding cell in "controllerDidChangeContent". The "indexPath" parameter has
            // value that we want in this case.
            deletedIndexPaths.append(indexPath!)
            break
        case .Update:
            println("Update an item.")
            // We don't expect Color instances to change after they are created. But Core Data would
            // notify us of changes if any occured. This can be useful if you want to respond to changes
            // that come about after data is downloaded. For example, when an images is downloaded from
            // Flickr in the Virtual Tourist app
            updatedIndexPaths.append(indexPath!)
            break
        case .Move:
            println("Move an item. We don't expect to see this in this app.")
            break
        default:
            break
        }
    }
    
    // This method is invoked after all of the changed in the current batch have been collected
    // into the three index path arrays (insert, delete, and upate). We now need to loop through the
    // arrays and perform the changes.
    //
    // The most interesting thing about the method is the collection view's "performBatchUpdates" method.
    // Notice that all of the changes are performed inside a closure that is handed to the collection view.
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        println("in controllerDidChangeContent. changes.count: \(insertedIndexPaths.count + deletedIndexPaths.count)")
        
        
        collectionView.performBatchUpdates({() -> Void in
            
            for indexPath in self.insertedIndexPaths {
                self.collectionView.insertItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
            
            }, completion: nil)
    }
    

    @IBAction func bottomButtonClicked(sender: AnyObject) {
        
        if selectedIndexes.isEmpty {
            deleteAllPhotos()
        } else {
            deleteSelectedPhotos()
        }
    }
    
    func deleteAllPhotos(){
        
        for photo in fetchedResultsController.fetchedObjects as! [Picture] {
            sharedContext.deleteObject(photo)
        }
        println(selectedPin.pictures.isEmpty)
        loadFromFlickr()
    }
    
    func deleteSelectedPhotos() {
        var photosToDelete = [Picture]()
        
        for indexPath in selectedIndexes {
            photosToDelete.append(fetchedResultsController.objectAtIndexPath(indexPath) as! Picture)
        }
        
        for photo in photosToDelete {
            sharedContext.deleteObject(photo)
        }
        
        saveContext()
        
        selectedIndexes = [NSIndexPath]()
        bottomButton.title = "New Collection"
    }
    
    func updateBottomButton(){
        if selectedIndexes.count > 0 {
            bottomButton.title = "Remove Selected Photos"
        } else {
            bottomButton.title = "New Collection"
        }
        
        //saveContext()
    }
    
    func setMapView() {
        let lat = CLLocationDegrees(selectedPin.latitude)
        let long = CLLocationDegrees(selectedPin.longitude)
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
        
        var annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        
        self.mapView.addAnnotation(annotation)
        
        let span = MKCoordinateSpan(latitudeDelta: CLLocationDegrees(2.0), longitudeDelta: CLLocationDegrees(2.0))
        
        let mapViewArea = MKCoordinateRegion(center: coordinate, span: span)
        self.mapView.setRegion(mapViewArea, animated: false)
        self.mapView.zoomEnabled = false
        self.mapView.scrollEnabled = false
        self.mapView.userInteractionEnabled = false
    }
    
}