//
//  ZZDeviceManager.swift
//  Harr KC's Hall
//
//


import UIKit

class ZZDeviceManager {
    static let shared = ZZDeviceManager()
    
    var deviceType: UIUserInterfaceIdiom
    
    private init() {
        self.deviceType = UIDevice.current.userInterfaceIdiom
    }
}
