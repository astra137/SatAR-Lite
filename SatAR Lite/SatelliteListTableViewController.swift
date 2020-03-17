import Foundation
import UIKit

class SatelliteListViewController: UITableViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // List all satellites, even untracked ones
        return Cache.list.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "cell")
        
        // Populate the name and visibility checkmark
        let sat = Cache.list[indexPath.row]
        
        cell.textLabel?.text = sat.tle.commonName
        
        if sat.tracking {
            cell.accessoryType = UITableViewCell.AccessoryType.checkmark
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // UITableViewCell.AccessoryType.<acc> may be useful
        
        // Toggle checkmark by mutating the struct in the list directly
        let sat = Cache.list[indexPath.row]
        sat.tracking = !sat.tracking
        
        if sat.tracking {
            tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.checkmark
        } else {
            tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.none
        }
    }
}
