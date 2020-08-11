//
//  ViewController.swift
//  ICSLocationManagerExampleSwift
//
//  Created by MIHIR PIPERMITWALA on 11/08/20.
//  Copyright © 2020 iCodeState. All rights reserved.
//

import UIKit
import CoreLocation
import ICSLocationManager

class ViewController: UIViewController, ICSLocationManagerDelegate {
    
    private var managerLocation: ICSLocationManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        managerLocation = ICSLocationManager(delegate: self, interval: 2)
        startLocation()
    }

    func startLocation() {
        if managerLocation.isRunning {
            managerLocation.stopUpdatingLocation()
        } else {
            
            if CLLocationManager.authorizationStatus() == .authorizedAlways {
                managerLocation.startUpdatingLocation(interval: 170, acceptableLocationAccuracy: 1000)
            } else {
                
                managerLocation.requestAlwaysAuthorization()
            }
        }
    }
    
    func scheduledLocationManager(_ manager: ICSLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }
    
    func scheduledLocationManager(_ manager: ICSLocationManager, didUpdateLocations locations: [CLLocation]) {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        if let coordinate = locations.first?.coordinate {
            print("longitude:-\(coordinate.longitude) , latitude:-\(coordinate.latitude)")
        }
    }
    
    func scheduledLocationManager(_ manager: ICSLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            print("notDetermined")
        case .restricted:
            print("restricted")
        case .denied:
            print("denied")
        case .authorizedAlways:
            print("authorizedAlways")
        case .authorizedWhenInUse:
            print("authorizedWhenInUse")
        @unknown default:
            print("default")
        }
    }
}
