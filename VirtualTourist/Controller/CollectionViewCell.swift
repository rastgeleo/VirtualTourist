//
//  CollectionViewCell.swift
//  VirtualTourist
//
//  Created by Sean Jeon on 09/02/2018.
//  Copyright © 2018 Sean Jeon. All rights reserved.
//

import UIKit

class CollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var photoView: UIImageView!
    
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!
    
    override var isSelected: Bool{
        didSet{

            photoView.alpha = isSelected ? 0.4 : 1
        }
    }
    
}
