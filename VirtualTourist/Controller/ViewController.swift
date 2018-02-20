//
//  ViewController.swift
//  VirtualTourist
//
//  Created by Sean Jeon on 08/02/2018.
//  Copyright © 2018 Sean Jeon. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class ViewController: UIViewController {

    //MARK: Properties
    let locationManager = CLLocationManager()
    var stack: CoreDataStack!
    let delegate = UIApplication.shared.delegate as! AppDelegate
    var editingPins:Bool = false
    
    //MARK: Outlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var warningLabel: UILabel!
    
    //MARK: Actions
    
    @IBAction func editPins(_ sender: Any) {
        editingPins = !editingPins
        warningLabel.text = "SELECT A PIN TO DELETE"
        
        guard let button = sender as? UIBarButtonItem else{
            return
        }
        if editingPins {
            button.title = "Done"
            UIView.animate(withDuration: 0.2){
                self.warningLabel.center.y -= self.warningLabel.bounds.height*2
            }
        } else{
            button.title = "Edit"
            UIView.animate(withDuration: 0.2){
                self.warningLabel.center.y += self.warningLabel.bounds.height*2
            }
        }
    }
    
    @IBAction func addNewAnnotation(_ recognizer: UILongPressGestureRecognizer) {
        
        if recognizer.state == .began && editingPins == false {
            let recognizedLocation = recognizer.location(in: mapView)
            let coordinate = mapView.convert(recognizedLocation, toCoordinateFrom: mapView)
            let newAnnotation = Annotation(coordinate: coordinate, context: stack!.context)
            mapView.addAnnotation(newAnnotation)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        stack = delegate.stack
        
        //setting mapview
        mapView.delegate = self
        checkLocationAuthorizationStatus()
        
        //fetch annotationdata
        
        loadAnnotations()
        setUI()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
 
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setUI(){
        warningLabel.layer.cornerRadius = 7.0
        warningLabel.layer.masksToBounds = true
        warningLabel.center.y += warningLabel.bounds.height*2
    }
    
}

extension ViewController: MKMapViewDelegate{
    
    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
         print(mapView.userLocation.coordinate)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        var annotationView: MKMarkerAnnotationView
        let identifier = "annotationIdentifier"
        
        if annotation.isEqual(mapView.userLocation){
            return nil
        }
        if let markerView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView{
            markerView.annotation = annotation
            annotationView = markerView
        } else{
            let markerView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            markerView.animatesWhenAdded = true
            annotationView = markerView
        }
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        // show picture sets that is saved
        
        guard delegate.isOnline else {
            warningLabel.text = "SORRY, IT SEEMS TO BE OFFLINE"
            UIView.animate(withDuration: 0.2, animations: {
                self.warningLabel.center.y -= self.warningLabel.bounds.height*2
            }, completion: { success in
                if success {
                    UIView.animate(withDuration: 0.2, delay: 0.5, options: [], animations: {
                        self.warningLabel.center.y += self.warningLabel.bounds.height*2
                    }, completion: nil)
                }
            })
            return
        }
        
        guard !editingPins else {
            
            if let annotation = view.annotation as? Annotation {
                mapView.removeAnnotation(view.annotation!)
                stack.context.delete(annotation)
            }
            return
        }
        
        if let annotation = view.annotation, annotation.isEqual(mapView.userLocation){
            print("user location marker selected")
            return
        }
        
        guard let annotation = view.annotation as? Annotation else{
            print("no annotation exist in annotation view")
            return
        }
        
        // make collection view controller
        let vc = storyboard?.instantiateViewController(withIdentifier: "collectionViewController") as! CollectionViewController
        vc.annotation = annotation
        
        // if theres no photoset saved, download new photoset
        if let photos = annotation.photos, photos.count != 0 {
            print("there is existing photo set")
            print(photos)
            loadCollectionViewController(with: annotation, vc: vc)
        
        } else{
             print ("there isn't existing photo set")
            self.loadCollectionViewControllerWithNewPhotoSet(with: annotation, vc: vc)
            
        }
            
        self.navigationController?.pushViewController(vc, animated: true)
    }

}

extension ViewController {
    
    // helper functuon to check location authrization
    func checkLocationAuthorizationStatus(){
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse{
            mapView.showsUserLocation = true
        } else{
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func loadAnnotations(){
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Annotation")
        var annotations: [NSManagedObject]?
        do {
            annotations = try stack.context.fetch(fetchRequest)
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
        
        if let annotations = annotations {
            mapView.addAnnotations(annotations as! [MKAnnotation])
        }
        
    }
    
    func loadCollectionViewController(with annotation: Annotation, vc: CollectionViewController){
        
        let fr = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
        let pred = NSPredicate(format: "annotation = %@", argumentArray: [annotation])
        fr.predicate = pred
        fr.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        let fc = NSFetchedResultsController(fetchRequest: fr, managedObjectContext: (self.stack?.context)!, sectionNameKeyPath: nil, cacheName: nil)
        
        vc.fetchedResultsController = fc // should be set in main thread only
    }
    
    func loadCollectionViewControllerWithNewPhotoSet(with annotation: Annotation, vc: CollectionViewController){
        
        let parameters = [
            Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
        ]
        
        FlickrClient.shared.getPageNumber(annotation, parameters: parameters){ (success, result, error) in
            
            if success {
                
                guard let pages = result else{
                    return
                }
                
                let upperBound = min(Constants.Flickr.maximumPages, pages)
                let pageNumber = Int(arc4random_uniform(UInt32(upperBound)))
                
                FlickrClient.shared.downloadImagePathsFromFlickr(annotation, parameters: parameters, pageNumber: pageNumber){(success, photoArray, error) in
                    
                    if success {
                        guard let photoArray = photoArray else {
                            return
                        }
                        
                        FlickrClient.shared.registerPhotoObjects(photoArray, annotation: annotation, workerContext: self.stack.context)
                        
                        self.loadCollectionViewController(with: annotation, vc: vc)
                        
                    } else if let error = error {
                        print(error)
                    }
                }
            }
        }
    }
    
}


