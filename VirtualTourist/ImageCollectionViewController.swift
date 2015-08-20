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
    
    //these arrays will be used to keep track of which cells need to be deleted/updated
    var selectedIndexes = [NSIndexPath]()
    
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    @IBOutlet weak var collectionView:UICollectionView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var bottomButton: UIBarButtonItem!
    
    // this is the variable for the pin that had been selected in the mapViewController. It was passed from there
    var selectedPin: Pin!
    
    //get a refrence to the CoreDataStackManager singleton
    var sharedContext = CoreDataStackManager.sharedInstance().managedObjectContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //this function sets the map view based on the selected pin
        setMapView()
        
        //this will fill the fetchedResultsController with all the images stored in URL
        var error: NSError?
        fetchedResultsController.performFetch(&error)
        
        if let error = error {
            println("Error performing initial fetch: \(error)")
        }
        
        //this will make sure the bottom button is correctly labeled, but unavailable at first
        updateBottomButton()
        if selectedPin.pictures.isEmpty {
            bottomButton.enabled = false
        }
        
        
    }
    
    //define the fetchedResultsController. The sort doesn't matter as long as it is consistant, also define the entityName that will be searched for
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Picture")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "picturePath", ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.selectedPin)
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        
        return fetchedResultsController
    } ()
    
    //call the loadFromFlickr right before the viewcontroller gets presented
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        loadFromFlickr()
    }
    
    //this method checks if the pictures array stored in the pin is empty. If yes, it will use the getImagesFromFlickrBySearch method to get a dictionary of all the pitures
    func loadFromFlickr() {
        if selectedPin.pictures.isEmpty {
            
            //method arguments needed for the flickr API
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
                            
                            //use the dictionary to create a bunch of picture objects and add them to the sharedContext
                            var photos = photoDictionaries.map() { (dictionary: [String: AnyObject]) -> Picture in
                                let photo = Picture(dictionary: dictionary, context: self.sharedContext)
                                
                                photo.pin = self.selectedPin
                                
                                return photo
                            }
                            
                            //once the picture urls are downloaded, make the bottom button enabled
                            dispatch_async(dispatch_get_main_queue()) {
                                
                                self.bottomButton.enabled = true
                            }
                        }
                    }
                }
            }
        }
    }
    
    // this function will make sure the collection view is full of pictures that are square and 3 across.
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
    
    // this is a helper function simply for saving the context
    func saveContext(){
        CoreDataStackManager.sharedInstance().saveContext()
        println("context has been saved ...probably")
    }
    
    // this is a helper function that will take a dequed Picture cell instance, the indexPath and a picture insance and set it up with an image if available
    func configureCell(cell: PictureCell, atIndexPath indexPath: NSIndexPath, picture: Picture) {
        var pictureImage = UIImage(named: "posterPlaceHolder")
        
        //set the image to the place holder image, make sure the activity indicator is visible and begin animating it
        cell.flickrPictureView.image = pictureImage
        cell.downloadIndicator.hidden = false
        cell.downloadIndicator.startAnimating()
        
        // if the picture has been downloaded previously and stored in cache, then stop and hide the activity indicator and make the image visible
        if picture.pictureImage != nil {
            cell.flickrPictureView.image = picture.pictureImage
            cell.downloadIndicator.stopAnimating()
            cell.downloadIndicator.hidden = true
        } else {
            
            // if the image hasn't been downloaded, start the task that will eventually download the image
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
        
        // this checks if the cell has been selected. if it has been, set it's opacity to a mere 50%
        if let index = find(selectedIndexes, indexPath) {
            cell.flickrPictureView.alpha = 0.5
        } else {
            cell.flickrPictureView.alpha = 1.0
        }
    }
    
    //set the number of sections availble, but set it to 0 if nothing is available
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    // get the numberOfItemsInSection from the fetchedResultsController
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        
        println("number Of Cells: \(sectionInfo.numberOfObjects)")
        return sectionInfo.numberOfObjects
    }
    
    //deque a cell, configure it and return that cell
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PictureCell", forIndexPath: indexPath) as! PictureCell
        
        let picture = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Picture
        
        //println("a cell has been updated at \(picture.picturePath)")
        
        self.configureCell(cell, atIndexPath: indexPath, picture: picture)
            
        return cell
    }
    
    //if a cell is touched, add it to the index of cells selected, then udpate the cell, this will make it highlighted this time. Awesome, right?!
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
    
    // MATTHEW: - Fetched Results Controller Delegate
    
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
                println("batch update")
            }
            
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
            
            }, completion: nil)
        
        // this part is tricky. This saves the context any time there is a change made. Since I don't want a change to occur that isn't persisted, this seems like the best place to put it
        saveContext()
    }
    
    // when the button is picked, if there are any selected indexes, call deleteSelectedPhotos, otherwise delete all the pictures and start over
    @IBAction func bottomButtonClicked(sender: AnyObject) {
        
        if selectedIndexes.isEmpty {
            deleteAllPhotos()
        } else {
            deleteSelectedPhotos()
        }
    }
    
    func deleteAllPhotos(){
        //delete all the photos in the fetcheResultsController
        for photo in fetchedResultsController.fetchedObjects as! [Picture] {
            sharedContext.deleteObject(photo)
        }
        
        // this makes sure that the fetchedReusltsController will be empty before loadFromFlickr is called
        saveContext()
        
        //make the bottom button unenabled until loadFromFlickr enables it at the appropriate time
        bottomButton.enabled = false
        loadFromFlickr()
    }
    
    func deleteSelectedPhotos() {
        var photosToDelete = [Picture]()
        
        //get the Picture objects at the locations in the selectedIndexes array and add them to the photosToDelete array
        for indexPath in selectedIndexes {
            photosToDelete.append(fetchedResultsController.objectAtIndexPath(indexPath) as! Picture)
        }
        
        //delete all the Pictures in the photosToDelete array
        for photo in photosToDelete {
            sharedContext.deleteObject(photo)
        }
        
        saveContext()
        
        //clear the selected indexes array with a new instance of the array
        selectedIndexes = [NSIndexPath]()
        updateBottomButton()
        
    }
    
    //set the title on the bottom button according to how many indexes have been selected
    func updateBottomButton(){
        if selectedIndexes.count > 0 {
            bottomButton.title = "Remove Selected Photos"
        } else {
            bottomButton.title = "New Collection"
        }
    }
    
    //this function uses the selectedPin object to set the center of the map, add an annotation at the location and set an abitraty span. It also disables zoom, scroll and user interaction
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