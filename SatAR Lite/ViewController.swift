import UIKit
import SceneKit
import ARKit
import CoreLocation

class ViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {
    
    var locationManager = CLLocationManager()
    var userLocation: CLLocation!
    
    var propagatorTimer: Timer!
    var satelliteNodes: [AmateurRadioSatellite:SCNNode] = [:]
    
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
        
        // Remove satellites in case they aren't tracked anymore
        for (_, node) in satelliteNodes { node.removeFromParentNode() }
        satelliteNodes.removeAll()
        
        // Create and attach nodes for tracked satellites
        for ars in Cache.list {
            if ars.tracking {
                // SceneKit/AR coordinates are in meters
                let plane = SCNPlane(width: 0.05, height: 0.05)
                plane.firstMaterial!.diffuse.contents = "🛰".image()!
                let node = SCNNode(geometry: plane)
                node.constraints = [SCNBillboardConstraint()]
                
                // Save and attach node
                satelliteNodes[ars] = node
                sceneView.scene.rootNode.addChildNode(node)
            }
        }
        
        // Update nodes every so often
        propagatorTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            self.propagateAll()
        }
        
        // Attempt immediate propagation when view appears
        self.propagateAll()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        // Stop propagating
        propagatorTimer.invalidate()
    }
    
    /// Propagates satellites to current time and updates nodes to match
    func propagateAll() {
        guard let location = self.userLocation else {
            print("Skipping propagation: no location yet")
            return
        }
        
        if satelliteNodes.count == 0 {
            print("Skipping propagation: nothing tracked")
            return
        }
        
        // Record time it takes to propagate
        let now = Date()
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        for (ars, node) in satelliteNodes {
            // Calculate next topocentric coord (south, east, up)
            let topo = ars.getTopo(date: now, lat: lat, lon: lon)
            let distance = topo.magnitude()
            
            // Place node in world (east, up, south)
            // Normalized to 1 meter from camera
            node.position.x = Float(topo.y / distance)
            node.position.y = Float(topo.z / distance)
            node.position.z = Float(topo.x / distance)
        }
        
        print("propagateAll: \(satelliteNodes.count) sats took \(Date().nanoseconds(from: now) / 1000) μs")
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
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            userLocation = location
        }
    }
}

