//
//  Photo+CoreDataClass.swift
//  VirtualTourist
//
//  Created by Sean Jeon on 08/02/2018.
//  Copyright © 2018 Sean Jeon. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Photo)
public class Photo: NSManagedObject {

    convenience init(title: String, photoUrl: URL, annotation: Annotation, context: NSManagedObjectContext) {
        
        // An EntityDescription is an object that has access to all
        // the information you provided in the Entity part of the model
        // you need it to create an instance of this class.
        if let ent = NSEntityDescription.entity(forEntityName: "Photo", in: context) {
            self.init(entity: ent, insertInto: context)
            self.title = title
            self.photoUrl = photoUrl
            self.annotation = annotation
            
        } else {
            fatalError("Unable to find Entity name!")
        }
    }
    
}
