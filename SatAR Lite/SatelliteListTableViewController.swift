import Foundation
import UIKit

class SatelliteListViewController: UITableViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // List all satellites, even untracked ones
        return Cache.tles.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "cell")
        
        // Populate the name and visibility checkmark
        let tle = Cache.tles[indexPath.row]
        
        cell.textLabel?.text = tle.commonName
        
        if tracking[tle.noradIndex] ?? false {
            cell.accessoryType = UITableViewCell.AccessoryType.checkmark
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // UITableViewCell.AccessoryType.<acc> may be useful
        
        // Toggle checkmark and visibility
        let tle = Cache.tles[indexPath.row]
        
        tracking[tle.noradIndex] = !(tracking[tle.noradIndex] ?? false)
        
        if (tracking[tle.noradIndex]!) {
            tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.checkmark
        } else {
            tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.none
        }
    }
}
