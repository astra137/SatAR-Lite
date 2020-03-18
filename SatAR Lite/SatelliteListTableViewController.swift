import Foundation
import UIKit

class SatelliteListViewController: UITableViewController, UISearchResultsUpdating {
    
    var filtered: [AmateurRadioSatellite] = []
    
    override func viewDidLoad() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search name or ID"
        searchController.searchBar.sizeToFit()
        
        navigationItem.searchController = searchController
        definesPresentationContext = true
        
        filtered = Cache.list
    }
    
    func filterContentForSearchText(_ searchText: String) {
        // TODO: NSPredicate?
        filtered = searchText.isEmpty ? Cache.list : Cache.list.filter { ars in
            return ars.tle.commonName.lowercased().contains(searchText.lowercased())
                || String(ars.tle.noradIndex).contains(searchText.lowercased())
        }
        
        tableView.reloadData()
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        filterContentForSearchText(searchBar.text!)
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // List all satellites, even untracked ones
        return filtered.count
    }
    
    // MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "cell")
        
        // Populate the name and visibility checkmark
        let sat = filtered[indexPath.row]
        
        cell.textLabel?.text = sat.tle.commonName
        
        if sat.tracking {
            cell.accessoryType = UITableViewCell.AccessoryType.checkmark
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // UITableViewCell.AccessoryType.<acc> may be useful
        
        let sat = filtered[indexPath.row]
        
        // Toggle checkmark by mutating the class in the list directly
        // This is a reference to the object in the Cache.list, so that will change too
        sat.tracking = !sat.tracking
        
        if sat.tracking {
            tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.checkmark
        } else {
            tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.none
        }
    }
}
