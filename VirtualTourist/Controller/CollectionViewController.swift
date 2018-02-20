//
//  CollectionViewController.swift
//  VirtualTourist
//
//  Created by Sean Jeon on 09/02/2018.
//  Copyright © 2018 Sean Jeon. All rights reserved.
//

import UIKit
import CoreData
import MapKit

class CollectionViewController: UIViewController {

    
    // MARK: Properties
    
    var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?{
        didSet{
            fetchedResultsController?.delegate = self
            executeSearch()
            if let collectionView = collectionView{
                collectionView.reloadData()
            }
        }
    }
    
    let delegate = UIApplication.shared.delegate as! AppDelegate
    var annotation: Annotation?
    var stack: CoreDataStack!
    var itemsToRemove = [IndexPath]()
    
    var shouldReloadData = false
    var deleting: Bool = false {
        didSet{
            
            guard deleting else {
                barButton.title = "New Collection"
                barButton.tag = 0
                return
            }
            
            barButton.title = "Delete Selected Items"
            barButton.tag = 1
        }
    }
    
    // MARK: Outlets
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var barButton: UIBarButtonItem!
    @IBOutlet weak var offlineLabel: UILabel!
    
    // MARK: Actions
    @IBAction func loadNewCollection(_ sender: Any) {
        
        if let sender = sender as? UIBarButtonItem, sender.tag == 0 {
        
            collectionView.isHidden = !delegate.isOnline
            
            guard delegate.isOnline else{
                offlineLabel.isHidden = false
                return
            }
            
            if let annotation = annotation, let fc = fetchedResultsController {
                
                shouldReloadData = true
                setUI(false)
                for object in fc.fetchedObjects!{
                    
                    fc.managedObjectContext.delete(object as! NSManagedObject)
                }
                
                downloadImagesFromFlickr(for: annotation)
                
                
            }
        } else if let sender = sender as? UIBarButtonItem, sender.tag == 1 {
            
            if let fc = fetchedResultsController{
                
                shouldReloadData = false
                for indexPath in itemsToRemove{
                    fc.managedObjectContext.delete(fc.object(at: indexPath) as! NSManagedObject)
                }
            }
            
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        stack = delegate.stack
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.allowsMultipleSelection = true
        
        setCollectionViewLayout()
        setMapView()
        setUI(false)
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setUI(true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stack.save()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using [segue destinationViewController].
        // Pass the selected object to the new view controller.
    }
    */


}

// MARK: Helper methods
extension CollectionViewController{
    
    func setUI(_ bool:Bool){
        
        // UI
        offlineLabel.isHidden = true
        barButton.isEnabled = bool
        
    }
    
    func setCollectionViewLayout(){
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = CGFloat(0.5)
        layout.minimumLineSpacing = CGFloat(0.5)
        let numberOfItems: CGFloat = 3.0
        let width =  (collectionView.frame.width - 2*layout.minimumInteritemSpacing)/numberOfItems
        let height = width
        layout.itemSize = CGSize(width: width, height: height)
        layout.sectionInset = UIEdgeInsetsMake(0, 0, 0, 0)
        collectionView.collectionViewLayout = layout
    }
    
    func setMapView(){
        if let annotation = annotation {
            
            mapView.addAnnotation(annotation)
            mapView.centerCoordinate = annotation.coordinate
            mapView.isZoomEnabled = false
            mapView.isScrollEnabled = false
            mapView.isPitchEnabled = false
            mapView.isRotateEnabled = false
            
            let location = CLLocation(latitude: annotation.latitude, longitude: annotation.longitude)
            let geoCoder = CLGeocoder()
            geoCoder.reverseGeocodeLocation(location){(placemarks, error) in
                
                if error == nil{
                    
                    let placemark = placemarks?[0]
                    self.title = placemark?.locality
                }
            }
        }
    }
    
   
    func downloadImagesFromFlickr(for annotation:Annotation){
        
        let coordinate = annotation.coordinate
        let parameters = [
            Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
            Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback,
            Constants.FlickrParameterKeys.BoundingBox: FlickrClient.shared.bboxString(coordinate)
            
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
                        self.setUI(true)
                        
                    } else if let error = error {
                        print(error)
                    }
                }
            }
        }
    
    }
    
}

// MARK: UICollectionView DataSource
extension CollectionViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        if let fc = fetchedResultsController {
            return (fc.sections?.count)!
        } else {
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of items
        if let fc = fetchedResultsController {
            return (fc.sections?[section].numberOfObjects)!
        } else {
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let reuseIdentifier = "Cell"
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! CollectionViewCell
        
        if let fetchedResultsController = fetchedResultsController{
            
            cell.indicatorView.startAnimating()
            let photoObject = fetchedResultsController.object(at: indexPath) as? Photo
            let photoUrl = photoObject?.photoUrl
            FlickrClient.shared.downloadImageFromUrl(photoUrl!){ (data, error) in
                cell.indicatorView.stopAnimating()
                cell.indicatorView.isHidden = true
                cell.photoView.image = UIImage(data: data!)
            }
            // Configure the cell
            
        }
        return cell
    }
}

// MARK: UICollectionView Delegate
extension CollectionViewController: UICollectionViewDelegate{

    // MARK: UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        deleting = true
        itemsToRemove.append(indexPath)
        print(itemsToRemove)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        
        if let index = itemsToRemove.index(of: indexPath) {
            itemsToRemove.remove(at: index)
            print(itemsToRemove)
            
            if itemsToRemove.isEmpty {
                deleting = false
            }
        }
    
    }

    /*
     // Uncomment this method to specify if the specified item should be highlighted during tracking
     override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
     return true
     }
     */
    
    /*
     // Uncomment this method to specify if the specified item should be selected
     override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
     return true
     }
     */
    
    /*
     // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
     override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
     return false
     }
     
     override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
     return false
     }
     
     override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
     
     }
     */
}

extension CollectionViewController {
    
    func executeSearch() {
        if let fc = fetchedResultsController {
            do {
                try fc.performFetch()
            } catch let e as NSError {
                print("Error while trying to perform a search: \n\(e)\n\(fc)")
            }
        }
    }
}

// MARK: - CoreDataTableViewController: NSFetchedResultsControllerDelegate

extension CollectionViewController: NSFetchedResultsControllerDelegate {
    
    /*
     func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
     collectionView.beginUpdates()
     
     }
     */
    
    /*
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        
        let set = IndexSet(integer: sectionIndex)
        
        switch (type) {
        case .insert:
            collectionView.insertSections(set)
        case .delete:
            collectionView.deleteSections(set)
        default:
            // irrelevant in our case
            break
        }
    }
    */
    
    /*
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        
        print("didChange delegate is called")
        if !shouldReloadData {
            switch(type) {
            case .insert:
                collectionView.insertItems(at: [newIndexPath!])
            case .delete:
                collectionView.deleteItems(at: [indexPath!])
            case .update:
                collectionView.reloadItems(at: [indexPath!])
            case .move:
                collectionView.deleteItems(at: [indexPath!])
                collectionView.insertItems(at: [newIndexPath!])
            }
        } else {
           return
        }
    }
    */
 
     func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if shouldReloadData {
            collectionView.reloadData()
            print("collectionview reloaded!")
        } else {
            collectionView.performBatchUpdates({
                collectionView.deleteItems(at: itemsToRemove)
            }, completion: { (success) in
                if success {
                    self.itemsToRemove.removeAll()
                    print(self.itemsToRemove)
                    self.deleting = false
                }
            })
        }
     }
    
}
