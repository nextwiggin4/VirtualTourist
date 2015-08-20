//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Matthew Dean Furlo on 7/21/15.
//  Copyright (c) 2015 FurloBros. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    //get a refrence to the CoreDataStackManager singleton
    var sharedContext = CoreDataStackManager.sharedInstance().managedObjectContext!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //this function will return the map to it's last saved location
        restoreMapRegion(false)
        
        var error: NSError?
        
        //this will fill the fetchedResultsController with all the pins stored in core data.
        fetchedResultsController.performFetch(&error)
        
        if let error = error {
            println("Unresolved error \(error), \(error.userInfo)")
            abort()
        }
        
        fetchedResultsController.delegate = self
        
        //finally, add all the annotations from the fetchedResultsController to the map
        addAnnotationsToMap()
        
    }
    
    //define the fetchedResultsController. There is no need to sort the results, just define the entityName that will be searched for
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        
        fetchRequest.sortDescriptors = []
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        return fetchedResultsController
    } ()

    //this is a simple helper variable for saving and getting the location of data (map center and zoom) persisted outside of the core data stack
    var filePath : String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first as! NSURL
        return url.URLByAppendingPathComponent("mapRegionArchive").path!
    }
    
    //this function stores the dictionary with the NSKeyedArchiver whenever it is called
    func saveMapRegion() {
        let dictionary = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]
        
        NSKeyedArchiver.archiveRootObject(dictionary, toFile: filePath)
    }
    
    //this function looks up the dictionary of saveMapRegion using the NSKeyedUnarchiver and uses the entries to set the center and span of the map
    func restoreMapRegion(animated: Bool) {
        if let regionDictionar = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [String: AnyObject] {
            let longitude = regionDictionar["longitude"] as! CLLocationDegrees
            let latitude = regionDictionar["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            let longitudeDelta = regionDictionar["latitudeDelta"] as! CLLocationDegrees
            let latitudeDelat = regionDictionar["longitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelat, longitudeDelta: longitudeDelta)
            
            let savedRegion = MKCoordinateRegion(center: center, span: span)
            
            mapView.setRegion(savedRegion, animated: animated)
            
        }
    }
    
    //
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        let controller = self.storyboard!.instantiateViewControllerWithIdentifier("ImageCollectionView") as! ImageCollectionViewController
        let selectedPinCoordinate = view.annotation.coordinate
        
        //this lets you reslect the same pin after popping the view controller, without having to touch outside the pin
        var selectedAnnotations = mapView.selectedAnnotations as! [MKAnnotation]
        for id in selectedAnnotations {
            mapView.deselectAnnotation(id, animated: false)
        }
        
        //fetch the updated results from Core Data, this make sure that all annotations are present
        var error: NSError?
        
        fetchedResultsController.performFetch(&error)
        
        if let error = error {
            println("Unresolved error \(error), \(error.userInfo)")
            abort()
        }
        
        //get the array of all stored pins
        var fetchedPins = self.fetchedResultsController.fetchedObjects as! [Pin]
        //loop through all the pins and check if their coordiantes match the coordiante of the seleceted pin. If yes, then navigate to the ImageCollectionViewController.
        for pin in fetchedPins {
            if selectedPinCoordinate.latitude == pin.latitude && selectedPinCoordinate.longitude == pin.longitude {
                controller.selectedPin = pin
                self.navigationController!.pushViewController(controller, animated: true)
            }
        }
    }
    
    //adds annotations for details
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            //pinView!.canShowCallout = true
            pinView!.pinColor = .Red
            //pinView!.rightCalloutAccessoryView = UIButton.buttonWithType(.DetailDisclosure) as! UIButton
            pinView!.animatesDrop = true
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    // This takes the details from array of strucs and turns them in to annotations. Those annotations are then added to mapView
    func addAnnotationsToMap() {
        
        //this clears any annotations currently on the map before adding after a reload
        self.mapView.removeAnnotations(mapView.annotations)
        
        var annotations = [MKPointAnnotation]()
        var fetchedPins = self.fetchedResultsController.fetchedObjects as? [Pin]
        
        
        if let fetchedPins = fetchedPins {
            for location in fetchedPins {
                let lat = CLLocationDegrees(location.latitude)
                let long = CLLocationDegrees(location.longitude)
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
                
                var annotation = MKPointAnnotation()
                annotation.coordinate = coordinate
                
                annotations.append(annotation)
            }
            
            self.mapView.addAnnotations(annotations)
        } else {
            println("no points were fectched...")
        }
    }

    // this function adds a pin to the map if there is a long press, it then saves the pin to core data.
    @IBAction func longPress(sender: AnyObject) {

        if sender.state == UIGestureRecognizerState.Began {
            var touchPoint = sender.locationInView(mapView)
            var newCoordinates = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)
            var annotation = Pin(location: newCoordinates, context: sharedContext)
            
            var newPoint = MKPointAnnotation()
            newPoint.coordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(annotation.latitude), longitude: CLLocationDegrees(annotation.longitude))
            
            self.mapView.addAnnotation(newPoint)
            
            CoreDataStackManager.sharedInstance().saveContext()
            
        }
    }
    
    // this function saves the map whenever it changes, so it's easy to come back to!
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
    }

}