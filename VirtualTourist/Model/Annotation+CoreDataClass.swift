//
//  Annotation+CoreDataClass.swift
//  VirtualTourist
//
//  Created by Sean Jeon on 08/02/2018.
//  Copyright © 2018 Sean Jeon. All rights reserved.
//
//

import Foundation
import CoreData
import MapKit

@objc(Annotation)
public class Annotation: NSManagedObject {

    convenience init(coordinate: CLLocationCoordinate2D, context: NSManagedObjectContext) {
        
        // An EntityDescription is an object that has access to all
        // the information you provided in the Entity part of the model
        // you need it to create an instance of this class.
        if let ent = NSEntityDescription.entity(forEntityName: "Annotation", in: context) {
            self.init(entity: ent, insertInto: context)
            self.latitude = coordinate.latitude
            self.longitude = coordinate.longitude
        } else {
            fatalError("Unable to find Entity name!")
        }
    }
}

extension Annotation: MKAnnotation{
    public var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
    }
    
}
