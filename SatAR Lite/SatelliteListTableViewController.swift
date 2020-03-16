import Foundation
import UIKit

class SatelliteListViewController: UITableViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // List all satellites, even untracked ones
        return Cache.sats.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "cell")
        
        // Populate the name and visibility checkmark
        let sat = Cache.sats[indexPath.row]
        
        cell.textLabel?.text = sat.commonName
        
        if tracking[sat.noradIndex] ?? false {
            cell.accessoryType = UITableViewCell.AccessoryType.checkmark
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // UITableViewCell.AccessoryType.<acc> may be useful
        
        // Toggle checkmark and visibility
        let sat = Cache.sats[indexPath.row]
        
        tracking[sat.noradIndex] = !(tracking[sat.noradIndex] ?? false)
        
        if (tracking[sat.noradIndex]!) {
            tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.checkmark
        } else {
            tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.none
        }
    }
}
