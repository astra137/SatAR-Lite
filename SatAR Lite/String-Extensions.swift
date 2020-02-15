//
//  String-Extensions.swift
//  SatAR Lite
//
//  Created by Mac on 2/14/20.
//  Copyright © 2020 Mac. All rights reserved.
//

import Foundation
import UIKit

extension String {

    // emoji to image based on https://stackoverflow.com/a/41021662/957768
    func image() -> UIImage? {
        let size = CGSize(width: 30, height: 35)
        UIGraphicsBeginImageContextWithOptions(size, false, 0);
        UIColor.white.set()
        let rect = CGRect(origin: CGPoint(), size: size)
        UIRectFill(CGRect(origin: CGPoint(), size: size))
        (self as NSString).draw(in: rect, withAttributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 30)])
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

}
