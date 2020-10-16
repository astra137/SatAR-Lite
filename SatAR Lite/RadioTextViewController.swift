import Foundation
import UIKit

class RadioTextViewController: UIViewController {
    
    @IBOutlet weak var Text: UITextView!
    
    /// To be set by segue-ing view
    public var ars: AmateurRadioSatellite?
    
    override func viewDidLoad() {
        // Lazy description layout via newlines-o-plenty
        Text.text = """
            \(ars!.tle.commonName) (\(ars!.tle.noradIndex))
            
            
            """ +
            ars!.radios.map {
                radio in """
                callsign: \(radio.callsign)
                mode: \(radio.mode)
                beacon: \(radio.beacon)
                downlink: \(radio.downlink)
                uplink: \(radio.uplink)
                
                
                """
            }.joined()
    }
}
