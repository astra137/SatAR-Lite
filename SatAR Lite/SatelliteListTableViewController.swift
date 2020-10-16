import Foundation
import UIKit

class SatelliteListViewController: UITableViewController, UISearchResultsUpdating {
    
    var satellites: [AmateurRadioSatellite] {
        get { (tabBarController as! TabBarController).satellites }
    }
    
    var filtered: [Int] = []
    
    override func viewDidLoad() {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search name or ID"
        searchController.searchBar.sizeToFit()
        
        navigationItem.searchController = searchController
        definesPresentationContext = true
        
        filtered = satellites.map { ars in ars.tle.noradIndex }
    }
    
    func filterContentForSearchText(_ searchText: String) {
        // TODO: NSPredicate?
        filtered = satellites.map { ars in ars.tle.noradIndex }
        filtered = searchText.isEmpty ? filtered : filtered.filter { number in
            let ars = satellites.first { $0.tle.noradIndex == number }!
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
        
        let selectedNoradIndex = filtered[indexPath.row]
        let ars = satellites.first { $0.tle.noradIndex == selectedNoradIndex }!
        
        // Populate the name and visibility checkmark
        cell.textLabel?.text = ars.tle.commonName
        
        if ars.tracking {
            cell.accessoryType = UITableViewCell.AccessoryType.checkmark
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // UITableViewCell.AccessoryType.<acc> may be useful
        
        let selectedNoradIndex = filtered[indexPath.row]
        let ars = satellites.first { $0.tle.noradIndex == selectedNoradIndex }!
        
        // Toggle checkmark by mutating the class in the list directly
        // This is a reference to the object in the Cache.list, so that will change too
        ars.tracking = !ars.tracking
        
        if ars.tracking {
            tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.checkmark
        } else {
            tableView.cellForRow(at: indexPath)?.accessoryType = UITableViewCell.AccessoryType.none
        }
    }
}
