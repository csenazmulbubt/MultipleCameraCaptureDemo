//
//  TriggerButton.swift
//  MultipleCaptureCameraDemo
//
//  Created by Nazmul on 14/08/2022.
//

import Foundation

import UIKit

class TriggerButton: UIButton {
   
    var buttonColor = UIColor.white {
        didSet {
            setNeedsDisplay()
        }
    }

    override var isEnabled: Bool {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        print("FRAME RECT",frame)
        backgroundColor = UIColor.clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = UIColor.clear
    }

    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        let length = min(bounds.width, bounds.height)
        let outerRect = CGRect(x: (bounds.width / 2) - (length / 2), y: (bounds.height / 2) - (length / 2), width: length, height: length)
        let borderWidth: CGFloat = 6.0
        let outerPath = UIBezierPath(ovalIn: outerRect.insetBy(dx: borderWidth, dy: borderWidth))
        outerPath.lineWidth = borderWidth

        buttonColor.setStroke()
        outerPath.stroke()

        let innerPath = UIBezierPath(ovalIn: outerRect.insetBy(dx: borderWidth + 5, dy: borderWidth + 5))
        if isEnabled {
            buttonColor.setFill()
        } else {
            UIColor.gray.setFill()
        }
        innerPath.fill()
    }
}

