//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by Sean Jeon on 14/02/2018.
//  Copyright © 2018 Sean Jeon. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData


class FlickrClient {
    
    static let shared = FlickrClient()
    
    let session = URLSession.shared
    
    private init() {}
    
    
    func taskForGetMethod(_ annotation: Annotation, parameters: [String:Any], pageNumber: Int?, completionHandlerForGet: @escaping(_ result: Any?, _ error: NSError?)-> Void) -> URLSessionTask{
        
        
        var parameters = parameters
        let coordinate = annotation.coordinate
        
        parameters[Constants.FlickrParameterKeys.BoundingBox] = bboxString(coordinate)
        print("bboxString: \(bboxString(coordinate))")
        
        if let pageNumber = pageNumber {
            parameters[Constants.FlickrParameterKeys.Page] = pageNumber
        }
        
        let url = flickrURLFromParameters(parameters)
        print(url)
        let request = URLRequest(url: url)
        
        let task = session.dataTask(with: request){ (data, response, error) in
            
            func displayError(_ error: String){
                print("Error occured: \(error)")
                let userInfo = [NSLocalizedDescriptionKey : error]
                completionHandlerForGet(nil, NSError(domain: "taskForGetMethod", code: 1, userInfo: userInfo))
            }
            
            guard error == nil else{
                displayError("There was an error with your request")
                return
            }
            
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else{
                displayError("StatusCode is other than 2xx")
                return
            }
            
            guard let data = data else{
                displayError("There was no data returned")
                return
            }
            
            let parsedResult: [String: Any]!
            do{
                parsedResult = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as! [String: Any]
                
            }catch{
                displayError("Failed to parse data into json \(data)")
                return
            }
        
            completionHandlerForGet(parsedResult, nil)
        }
        
        task.resume()
        return task
    }
    
    func getPageNumber(_ annotation: Annotation, parameters: [String:Any], completionHandler: @escaping(_ sucess: Bool, _ result: Int?, _ error: String?)->Void){
        
        
        let _ = taskForGetMethod(annotation, parameters: parameters, pageNumber: nil){ (parsedResult, error) in
            
            func displayError(_ error: String){
                print("Error occured: \(error)")
                completionHandler(false, nil, error)
            }
            
            guard error == nil else {
                displayError("error occured while fetch page number")
                return
            }
            
                
            guard let parsedResult = parsedResult as? [String: Any] else{
                displayError("parsed result is nil")
                return
            }
            
            guard let photos = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String: Any] else{
                displayError("Couldn't find a key \(Constants.FlickrResponseKeys.Photos)")
                return
            }
            
            guard let pages = photos[Constants.FlickrResponseKeys.Pages] as? Int else{
                displayError("Couldn't find a key \(Constants.FlickrResponseKeys.Pages)")
                return
            }
            
            completionHandler(true, pages, nil)
                
           
        }
            
    }
    
    func downloadImagePathsFromFlickr(_ annotation: Annotation, parameters: [String:Any], pageNumber: Int?, completionHandler: @escaping(_ sucess: Bool, _ result: [[String: Any]]?, _ error: String?)->Void){
        
        
        let _ = taskForGetMethod(annotation, parameters: parameters, pageNumber: pageNumber){ (parsedResult, error) in
            
            func displayError(_ error: String){
                print("Error occured: \(error)")
                completionHandler(false, nil, error)
            }
            
            guard error == nil else{
                displayError("failed to download image path")
                return
            }
                
            guard let parsedResult = parsedResult as? [String: Any] else{
                displayError("parsed result is nil")
                return
            }
            
            guard let photos = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String: Any] else{
                displayError("Couldn't find a key \(Constants.FlickrResponseKeys.Photos)")
                return
            }
            
            guard let photoArray = photos[Constants.FlickrResponseKeys.Photo] as? [[String: Any]] else{
                displayError("Couldn't find a key \(Constants.FlickrResponseKeys.Photo)")
                return
            }
            
            if photoArray.count == 0 {
                displayError("photo array count is 0")
            } else{
                DispatchQueue.main.async {
                    completionHandler(true, photoArray, nil)
                }
            }
            
        }
    }
    
    func downloadImageFromUrl(_ url:URL, completionHandler: @escaping (_ data:Data?, _ error:String?)->Void){
        
        let task = session.dataTask(with: url){ (data, response, error) in
            
            func displayError(_ error: String){
                print("Error occured: \(error)")
                completionHandler(nil, error)
            }
            
            guard error == nil else{
                displayError("There was an error with your request")
                return
            }
            
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode >= 200 && statusCode <= 299 else{
                displayError("StatusCode is other than 2xx")
                return
            }
            
            guard let data = data else{
                displayError("There was no data returned")
                return
            }
            
            DispatchQueue.main.async {
                completionHandler(data, nil)
            }
            
        }
        task.resume()
    }
}

extension FlickrClient {
    
    func registerPhotoObjects(_ photoArray:[[String: Any]], annotation: Annotation, workerContext: NSManagedObjectContext){
        
        let randomIndexNumbers = getrandomIndex(upperBound: photoArray.count, howManyof: min(15, photoArray.count))
        
        for index in randomIndexNumbers {
            
            guard let title = photoArray[index][Constants.FlickrResponseKeys.Title] as? String else{
                print("Couldn't find a key \(Constants.FlickrResponseKeys.Title)")
                return
            }
            
            guard let photoUrl = photoArray[index][Constants.FlickrResponseKeys.MediumURL] as? String else{
                print("Couldn't find a key \(Constants.FlickrResponseKeys.MediumURL)")
                return
            }
            
            let imageUrl = URL(string: photoUrl)!
            
            let _ = Photo(title: title, photoUrl: imageUrl, annotation: annotation, context: workerContext)
        }
        
        print("new photos set to annotation")
        
    }
  
    
    func flickrURLFromParameters(_ parameters: [String:Any]) -> URL{
        var components = URLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [URLQueryItem]()
        
        for (key, value) in parameters{
            let queryItem = URLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
            
        }
        return components.url!
    }
    
    func bboxString(_ coordinate:CLLocationCoordinate2D) -> String{
        
        let longitude = coordinate.longitude
        let latitude = coordinate.latitude
        let minimumLon = max(longitude - Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.0)
        let minimumLat = max(latitude - Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.0)
        let maximumLon = min(longitude + Constants.Flickr.SearchBBoxHalfWidth, Constants.Flickr.SearchLonRange.1)
        let maximumLat = min(latitude + Constants.Flickr.SearchBBoxHalfHeight, Constants.Flickr.SearchLatRange.1)
        
        return "\(minimumLon),\(minimumLat),\(maximumLon),\(maximumLat)"
    }
    
    func getrandomIndex(upperBound:Int, howManyof:Int) -> [Int]{
        
        var arrayOfRandomIndex = [Int]()
        
        while arrayOfRandomIndex.count < howManyof{
            let randomIndex = Int(arc4random_uniform(UInt32(upperBound)))
            if !arrayOfRandomIndex.contains(randomIndex){
                arrayOfRandomIndex.append(randomIndex)
            }
        }
        return arrayOfRandomIndex
    }
    
}
