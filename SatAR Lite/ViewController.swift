import UIKit
import SceneKit
import ARKit
import CoreLocation

class ViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate {

    var satellites: [AmateurRadioSatellite] {
        get { (tabBarController as! TabBarController).satellites }
    }
    
    var locationManager = CLLocationManager()
    var userLocation: CLLocation!
    
    var propagatorTimer: Timer!
    var sat2node: [AmateurRadioSatellite:SCNNode] = [:]
    
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
        
        // React to taps
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap))
        self.sceneView.addGestureRecognizer(tap)
    }
    
    var segueTargetValue: AmateurRadioSatellite?
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let vc = segue.destination as! RadioTextViewController
        vc.ars = segueTargetValue
    }
    
    @objc func onTap(sender: UITapGestureRecognizer) {
        let sceneView = sender.view as! ARSCNView
        let location = sender.location(in: sceneView)
        let results = sceneView.hitTest(location, options: [SCNHitTestOption.searchMode : 1])
        
        for result in results {
            if let id = Int(result.node.name!) {
                print("tapped sat", id)
                segueTargetValue = satellites.first { $0.tle.noradIndex == id }
                performSegue(withIdentifier: "ShowSat", sender: self)
            } else {
                print("tapped unknown")
            }
        }
    }
    
    func lineFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> SCNGeometry {
        let indices: [Int32] = [0, 1]
        
        let source = SCNGeometrySource(vertices: [vector1, vector2])
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        
        return SCNGeometry(sources: [source], elements: [element])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = AROrientationTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        // Remove all satellites to un-track them
        for (_, node) in sat2node { node.removeFromParentNode() }
        sat2node.removeAll()
        
        // Create and attach nodes for tracked satellites only
        for ars in satellites {
            if ars.tracking {
                let id = String(ars.tle.noradIndex)
                
                // SceneKit/AR coordinates are in meters
                let sphere = SCNSphere(radius: 0.05)
                let baseNode = SCNNode(geometry: sphere)
                baseNode.constraints = [SCNBillboardConstraint()]
                baseNode.name = id
                
                let plane = SCNPlane(width: 0.5, height: 0.5)
                plane.firstMaterial!.diffuse.contents = "🛰".image()!
                let node2 = SCNNode(geometry: plane)
                
                node2.name = id
                baseNode.addChildNode(node2)
                
                let txt = SCNText(string: ars.tle.commonName, extrusionDepth: 0.01)
                txt.font = UIFont(name: "Arial", size: 0.2)
                txt.firstMaterial!.diffuse.contents = UIColor.white
                txt.firstMaterial!.specular.contents = UIColor.white
                let txtNode = SCNNode(geometry: txt)
                
                let (min, max) = txtNode.boundingBox
                let dx = min.x + 0.5 * (max.x - min.x)
                let dy = min.y + 0.5 * (max.y - min.y)
                let dz = min.z + 0.5 * (max.z - min.z)
                txtNode.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
                txtNode.position.y = 0.5
                
                txtNode.name = id
                baseNode.addChildNode(txtNode)
                
                // Save and render node
                sat2node[ars] = baseNode
                sceneView.scene.rootNode.addChildNode(baseNode)
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
        
        if sat2node.count == 0 {
            print("Skipping propagation: nothing tracked")
            return
        }
        
        // Record time it takes to propagate
        let now = Date()
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        
        for (ars, node) in sat2node {
            // Calculate next topocentric coord (south, east, up)
            let topo = ars.getTopo(date: now, lat: lat, lon: lon)
            let distance = topo.magnitude()
            
            // Place node in world (east, up, south)
            // Normalized to 10 meters from camera
            node.position.x = Float(topo.y / distance * 10)
            node.position.y = Float(topo.z / distance * 10)
            node.position.z = Float(topo.x / distance * 10)
        }
        
        print("propagateAll: \(sat2node.count) sats took \(Date().nanoseconds(from: now) / 1000) μs")
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

