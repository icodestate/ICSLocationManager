//
//  ICSLocationManager.swift
//  ICSLocationManager
//
//  Created by MIHIR PIPERMITWALA on 11/08/20.
//  Copyright © 2020 iCodeState. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import BackgroundTasks

public protocol ICSLocationManagerDelegate {
    func scheduledLocationManager(_ manager: ICSLocationManager, didFailWithError error: Error)
    func scheduledLocationManager(_ manager: ICSLocationManager, didUpdateLocations locations: [CLLocation])
    func scheduledLocationManager(_ manager: ICSLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
}

private struct ICSDateStruct {
    var minute: Int
    var hour: Int
}

public class ICSLocationManager: NSObject, CLLocationManagerDelegate {
    
    private let maxBGTime: TimeInterval = 170
    private let minBGTime: TimeInterval = 2
    private let minAcceptableLocationAccuracy: CLLocationAccuracy = 5
    private let waitForLocationsTime: TimeInterval = 3
    
    private let delegate: ICSLocationManagerDelegate
    private let manager = CLLocationManager()
    
    private var isManagerRunning = false
    private var checkLocationTimer: Timer?
    private var waitTimer: Timer?
    private var bgTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    private var lastLocations = [CLLocation]()
    
    public private(set) var acceptableLocationAccuracy: CLLocationAccuracy = 100
    public private(set) var checkLocationInterval: TimeInterval = 10
    public private(set) var isRunning = false
    
    private var intervalLocation = 2
    private var previousDate: ICSDateStruct?
    
    
    public init(delegate: ICSLocationManagerDelegate, interval: Int = 2) {
        
        self.delegate = delegate
        self.intervalLocation = interval
        super.init()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute,.hour], from: Date())
        previousDate = ICSDateStruct.init(minute: (components.minute ?? 0), hour: (components.hour ?? 0))
        configureLocationManager()
    }
    
    private func configureLocationManager(){
        
        manager.allowsBackgroundLocationUpdates = true
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.delegate = self
    }
    
    public func requestAlwaysAuthorization() {
        
        manager.requestAlwaysAuthorization()
    }
    
    
    public func startUpdatingLocation(interval: TimeInterval, acceptableLocationAccuracy: CLLocationAccuracy = 100) {
        
        if isRunning {
            
            stopUpdatingLocation()
        }
        
        checkLocationInterval = interval > MaxBGTime ? MaxBGTime : interval
        checkLocationInterval = interval < MinBGTime ? MinBGTime : interval
        
        self.acceptableLocationAccuracy = acceptableLocationAccuracy < MinAcceptableLocationAccuracy ? MinAcceptableLocationAccuracy : acceptableLocationAccuracy
        
        isRunning = true
        
        addNotifications()
        startLocationManager()
    }
    
    public func stopUpdatingLocation() {
        
        isRunning = false
        
        stopWaitTimer()
        stopLocationManager()
        stopBackgroundTask()
        stopCheckLocationTimer()
        removeNotifications()
    }
    
    private func addNotifications() {
        
        removeNotifications()
        
        NotificationCenter.default.addObserver(self, selector:  #selector(applicationDidEnterBackground),
                                               name: UIScene.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self, selector:  #selector(applicationDidBecomeActive),
                                               name: UIScene.didActivateNotification,
                                               object: nil)
    }
    
    private func removeNotifications() {
        
        NotificationCenter.default.removeObserver(self)
    }
    
    private func startLocationManager() {
        
        isManagerRunning = true
        manager.startUpdatingLocation()
    }
    
    private func stopLocationManager() {
        
        isManagerRunning = false
        manager.stopUpdatingLocation()
    }
    
    @objc func applicationDidEnterBackground() {
        
        stopBackgroundTask()
        startBackgroundTask()
    }
    
    @objc func applicationDidBecomeActive() {
        
        stopBackgroundTask()
    }
    
    
    
    private func startCheckLocationTimer() {
        
        stopCheckLocationTimer()
        
        checkLocationTimer = Timer.scheduledTimer(timeInterval: checkLocationInterval, target: self, selector: #selector(checkLocationTimerEvent), userInfo: nil, repeats: false)
    }
    
    private func stopCheckLocationTimer() {
        
        if let timer = checkLocationTimer {
            
            timer.invalidate()
            checkLocationTimer=nil
        }
    }
    
    @objc func checkLocationTimerEvent() {
        
        stopCheckLocationTimer()
        
        startLocationManager()
        
        // starting from iOS 7 and above stop background task with delay, otherwise location service won't start
        self.perform(#selector(stopAndResetBgTaskIfNeeded), with: nil, afterDelay: 1)
    }
    
    private func startWaitTimer() {
        stopWaitTimer()
        
        waitTimer = Timer.scheduledTimer(timeInterval: intervalLocation, target: self, selector: #selector(waitTimerEvent), userInfo: nil, repeats: false)
    }
    
    private func stopWaitTimer() {
        
        if let timer = waitTimer {
            
            timer.invalidate()
            waitTimer=nil
        }
    }
    
    @objc func waitTimerEvent() {
        
        stopWaitTimer()
        
        if acceptableLocationAccuracyRetrieved() {
            
            startBackgroundTask()
            startCheckLocationTimer()
            stopLocationManager()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.minute,.hour], from: Date())
            if  ((previousDate?.minute ?? 0) + (intervalLocation - 1)) < (components.minute ?? 0) {
                delegate.scheduledLocationManager(self, didUpdateLocations: lastLocations)
            }
        }else{
            
            startWaitTimer()
        }
    }
    
    private func acceptableLocationAccuracyRetrieved() -> Bool {
        
        let location = lastLocations.last!
        
        return location.horizontalAccuracy <= acceptableLocationAccuracy ? true : false
    }
    
    func stopAndResetBgTaskIfNeeded()  {
        
        if isManagerRunning {
            stopBackgroundTask()
        }else{
            stopBackgroundTask()
            startBackgroundTask()
        }
    }
    
    private func startBackgroundTask() {
        let state = UIApplication.shared.applicationState
        
        if ((state == .background || state == .inactive) && bgTask == UIBackgroundTaskIdentifier.invalid) {
            
            bgTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                
                self.checkLocationTimerEvent()
            })
        }
    }
    
    @objc private func stopBackgroundTask() {
        guard bgTask != UIBackgroundTaskIdentifier.invalid else { return }
        
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = UIBackgroundTaskIdentifier.invalid
    }
}

extension ICSLocationManager: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        delegate.scheduledLocationManager(self, didChangeAuthorization: status)
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
        delegate.scheduledLocationManager(self, didFailWithError: error)
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard isManagerRunning else { return }
        guard locations.count>0 else { return }
        
        lastLocations = locations
        
        if waitTimer == nil {
            startWaitTimer()
        }
    }
}
