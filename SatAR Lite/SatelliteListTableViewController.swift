import Foundation
import UIKit

class SatelliteListViewController: UITableViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // List all satellites, even untracked ones
        return Cache.noradIds.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "cell")
        
        // Populate the name and visibility checkmark
        let noradId = Cache.noradIds[indexPath.row]
        
        cell.textLabel?.text = Cache.tles[noradId]?.commonName
        
        if tracking[noradId] ?? false {
            cell.accessoryType = UITableViewCell.AccessoryType.checkmark
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // UITableViewCell.AccessoryType.<acc> may be useful
        
        // Toggle checkmark and visibility
        let noradId = Cache.noradIds[indexPath.row]
        
        tracking[noradId] = !(tracking[noradId] ?? false)
        
        if (tracking[noradId]!) {
            tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.checkmark
        } else {
            tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.none
        }
    }
}
