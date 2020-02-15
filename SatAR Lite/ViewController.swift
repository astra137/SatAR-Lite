//
//  ViewController.swift
//  SatAR Lite
//
//  Created by Mac on 2/14/20.
//  Copyright © 2020 Mac. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import CoreLocation
import SatelliteKit

class ViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {
    
    var locationManager = CLLocationManager()
    var userLocation: CLLocation!
    
    var node: SCNNode!
    var sat: Satellite!
    
    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Get location going
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = AROrientationTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ARSCNViewDelegate
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    //MARK: - CLLocationManager
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Implementing this method is required
        print(error.localizedDescription)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            locationManager.requestLocation()
        }
    }
    
    func makeBillboardNode(_ image: UIImage) -> SCNNode {
        // SceneKit/AR coordinates are in meters
        let plane = SCNPlane(width: 0.1, height: 0.1)
        plane.firstMaterial!.diffuse.contents = image
        let node = SCNNode(geometry: plane)
        node.constraints = [SCNBillboardConstraint()]
        return node
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            
            if (node == nil) {
                node = makeBillboardNode("🛰".image()!)
                sceneView.scene.rootNode.addChildNode(node)
            }
            
            if sat == nil {
                let tle = try! TLE("BUGSAT 1",
                                   "1 40014U 14033E   20046.14221677 -.00000307  00000-0 -21767-4 0  9991",
                                   "2 40014  98.0475   4.5247 0031640 343.2517  16.7681 14.95391601308587")
                
                sat = Satellite(withTLE: tle)
                print(sat.debugDescription())
            }
            
            let now = Date().julianDate
            let posInKms = sat.position(julianDays: now)
            
            let obs = LatLonAlt(
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude,
                alt: 0)
            
            // Verified this function spits correct data out
            print(eci2geo(julianDays: now, celestial: posInKms))
            
            // Temp func for getting topocentric coords
            // Normalize satellite to 1 meter away
            let top = eci2top_fixed(julianDays: now, satVector: posInKms, geoVector: obs)
            node.worldPosition.z = Float(top.x / top.magnitude()) // South
            node.worldPosition.x = Float(top.y / top.magnitude()) // East
            node.worldPosition.y = Float(top.z / top.magnitude()) // Up
        }
    }
    
    public func eci2top_fixed(julianDays: Double, satVector: Vector, geoVector: LatLonAlt) -> Vector {
        let     latitudeRads = geoVector.lat * deg2rad
        let     sinLatitude = sin(latitudeRads)
        let     cosLatitude = cos(latitudeRads)
        
        let obsVector = geo2eci(julianDays: julianDays, geodetic: geoVector)
        let obs2sat = satVector - obsVector
        
        let     siderealRads = siteMeanSiderealTime(julianDate: julianDays, geoVector.lon) * deg2rad
        let     sinSidereal = sin(siderealRads)
        let     cosSidereal = cos(siderealRads)
        
        let topS = +sinLatitude * cosSidereal * obs2sat.x +
            sinLatitude * sinSidereal * obs2sat.y -
            cosLatitude * obs2sat.z
        
        let topE = -sinSidereal * obs2sat.x +
            cosSidereal * obs2sat.y
        
        let topZ = +cosLatitude * cosSidereal * obs2sat.x +
            cosLatitude * sinSidereal * obs2sat.y +
            sinLatitude * obs2sat.z
        
        return Vector(topS, topE, topZ)
    }
}
