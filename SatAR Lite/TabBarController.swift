import Foundation
import UIKit
import AwaitKit

class TabBarController: UITabBarController {
    /// Central list of satellite data
    public var satellites: [AmateurRadioSatellite] = []
    
    override func viewDidLoad() {
        DispatchQueue.main.async {
            do {
                // Load all satellite data in this controller
                // That way a singleton isn't required
                self.satellites = try await(Cache.loadAll())
                // self.selectedIndex = 0
            } catch {
                print(error)
            }
        }
    }
}
