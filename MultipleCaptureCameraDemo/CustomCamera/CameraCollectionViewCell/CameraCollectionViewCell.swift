//
//  CameraCollectionViewCell.swift
//  MultipleCaptureCameraDemo
//
//  Created by Nazmul on 14/08/2022.
//

import UIKit

protocol CameraCollectionViewDelegate: NSObjectProtocol{
    func tappedOnDeleteBtn(cell: CameraCollectionViewCell)
}

class CameraCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var deleteBtn: UIButton!
    
    weak var cameraCellDelegate: CameraCollectionViewDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.layer.cornerRadius = 8
        self.contentView.clipsToBounds = true
        // Initialization code
    }
    
    @IBAction func tappedOnDeleteBtn(_ sender: UIButton) {
        cameraCellDelegate?.tappedOnDeleteBtn(cell: self)
    }
}
