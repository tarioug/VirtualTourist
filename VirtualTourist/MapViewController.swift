//
//  ViewController.swift
//  VirtualTourist
//
//  Created by Nawfal on 01/09/2015.
//  Copyright (c) 2015 Noufel Gouirhate. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var tapPinsToDeleteLabel: UILabel!
    var arrayOfPinsToPersist = [Pin]()

    var deleteMode = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: UIBarButtonItemStyle.Done, target: self, action: "editPins")
        
        restoreMapRegion(false)
        

        tapPinsToDeleteLabel.hidden = true
            
        let longPressRecogniser = UILongPressGestureRecognizer(target: self, action: "handleLongPress:")
            
        longPressRecogniser.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPressRecogniser)
        handleLongPress(longPressRecogniser)



        
        arrayOfPinsToPersist = fetchAllPins()
        var annotations = [MKPointAnnotation]()
        
        for pin in arrayOfPinsToPersist {
            
            // The lat and long are used to create a CLLocationCoordinates2D instance.
            let coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
            
            // Here we create the annotation and set its coordiate, title, and subtitle properties
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            
            annotations.append(annotation)
        }
        
        // When the array is complete, we add the annotations to the map.
        self.mapView.addAnnotations(annotations)
    }
    
    // MARK: -
    func editPins() {
        if deleteMode == false {
            deleteMode = true
            tapPinsToDeleteLabel.hidden = false
            print("In Normal Mode")
        } else {
            deleteMode = false
            tapPinsToDeleteLabel.hidden = true
            print("In Delete Mode")
        }
        
    }
    
    // MARK: - Map Region
    func restoreMapRegion(animated: Bool) {
        if let regionDictionary = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [String : AnyObject] {
            
            let longitude = regionDictionary["longitude"] as! CLLocationDegrees
            let latitude = regionDictionary["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            let longitudeDelta = regionDictionary["latitudeDelta"] as! CLLocationDegrees
            let latitudeDelta = regionDictionary["longitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            
            let savedRegion = MKCoordinateRegion(center: center, span: span)
            
            mapView.setRegion(savedRegion, animated: animated)
        }
    }
    
    func saveMapRegion() {
        let dictionary = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]
        
        NSKeyedArchiver.archiveRootObject(dictionary, toFile: filePath)
        
    }
    
    
    // MARK: - Mapkit Methods
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        let annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "pin")
        annotationView.animatesDrop = true
        annotationView.canShowCallout = false
        
        return annotationView
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        
        let coordinate = CLLocationCoordinate2DMake(view.annotation!.coordinate.latitude, view.annotation!.coordinate.longitude)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        
        if deleteMode {
            print("In delete mode")
            mapView.removeAnnotation(view.annotation!)
            for pin in self.fetchAllPins() {
                
                if (pin.latitude == annotation.coordinate.latitude) && (pin.longitude == annotation.coordinate.longitude) {
                    
                    self.sharedContext.deleteObject(pin)
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        CoreDataStackManager.sharedInstance().saveContext()
                    }                }
            }
            
        } else {
            print("Not in delete mode")
            
            let photoViewController = self.storyboard!.instantiateViewControllerWithIdentifier("photoViewController") as! PhotoViewController
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                
                for pin in self.fetchAllPins() {
                    photoViewController.pin = pin
                    print("array of photos not empty")
                }
                self.navigationController!.pushViewController(photoViewController, animated: true)
                
            })
        }
        
    }

    

    // MARK: - Long gesture
    //http://stackoverflow.com/questions/3959994/how-to-add-a-push-pin-to-a-mkmapviewios-when-touching
    func handleLongPress(gestureRecognizer : UIGestureRecognizer){
            if deleteMode == false {
                if gestureRecognizer.state != .Began {
                    return
                }
        
                let touchPoint = gestureRecognizer.locationInView(self.mapView)
                let touchMapCoordinate = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)
    
                _ = touchMapCoordinate.latitude as Double
                _ = touchMapCoordinate.longitude as Double
        
                let pinToBeAdded = Pin(latitude: touchMapCoordinate.latitude, longitude: touchMapCoordinate.longitude, context: self.sharedContext)
        
                let annotation = MKPointAnnotation()
                annotation.coordinate = touchMapCoordinate
        
                arrayOfPinsToPersist.append(pinToBeAdded)
        
                mapView.addAnnotation(annotation)
        
                var error: NSError? = nil
                do {
                    try self.sharedContext.save()
                } catch let error1 as NSError {
                    error = error1
                }
                if let error = error {
                    print("error saving context: \(error.localizedDescription)")
                }
            }
    }
    
    
    // MARK: - Core Data
    
    func fetchAllPins() -> [Pin] {
        let error: NSErrorPointer = nil
        
        // Create the Fetch Request
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        
        // Execute the Fetch Request
        let results: [AnyObject]?
        do {
            results = try sharedContext.executeFetchRequest(fetchRequest)
        } catch let error1 as NSError {
            error.memory = error1
            results = nil
        }
        
        // Check for Errors
        if error != nil {
            print("Error in fectchAllActors(): \(error)")
        }
        
        // Return the results, cast to an array of Person objects
        return results as! [Pin]
    }

    
    lazy var sharedContext: NSManagedObjectContext =  {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }()
    
    var filePath: String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory,
		inDomains: .UserDomainMask).first as NSURL!
        return url.URLByAppendingPathComponent("mapRegionArchive").path!
    }
    
    func saveContext() {
        CoreDataStackManager.sharedInstance().saveContext()
    }
}


