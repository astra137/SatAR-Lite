import Foundation
import SatelliteKit
import PromiseKit
import AwaitKit
import PMKFoundation
import CSV

/// Amateur radio satellite with ham radio frequencies and modes
struct ARS {
    let commonName: String
    let noradIndex: Int?
    let uplink: String
    let downlink: String
    let beacon: String
    let mode: String
    let callsign: String
    let status: String
    
    init(fromJE9PEL row: [String]) throws {
        guard row.count == 8 else {
            throw ARSError.badJE9PEL
        }
        
        commonName = row[0]
        noradIndex = Int(row[1])
        uplink = row[2]
        downlink = row[3]
        beacon = row[4]
        mode = row[5]
        callsign = row[6]
        status = row[7]
    }
    
    enum ARSError: Error {
        case badJE9PEL
    }
}

/// Temporary global cache struct
/// TODO: replace this with data in views
struct Cache {
    
    /// Cached satellite orbital data
    static var tles: [TLE] = []
    
    /// Cached satellite radio data
    static var arss: [ARS] = []
    
    /// Secret stash of propagators
    private static var satellites: [Int:Satellite] = [:]
    
    /// Create satellite and propagator if necessary
    static func getSat(noradId: Int) -> Satellite {
        guard let sat = satellites[noradId] else {
            let tle = tles.first { tle in tle.noradIndex == noradId }!
            let sat = Satellite(withTLE: tle)
            satellites[noradId] = sat
            return sat
        }
        
        return sat
    }
    
    /// Calculate next topocentric coordinates (south, east, up)
    static func getTopo(noradId: Int, date: Date, lat: Double, lon: Double) -> Vector {
        let julian = date.julianDate
        let obs = LatLonAlt(lat: lat, lon: lon, alt: 0)
        
        // Load propagator from memory
        let sat = getSat(noradId: noradId)
        
        // Run propagator
        let eci = sat.position(julianDays: julian)
        
        // Calc topocentric coords (x south, y east, z up)
        return eci2top(julianDays: julian, satCel: eci, obsLLA: obs)
    }
    
    /// Download and cache both satellite and radio data
    static func loadAll() -> Promise<Void> {
        async {
            try await(when(fulfilled: [
                loadTLEs(),
                loadRadioData()
            ]))
            
            // TODO: debugging
            // Search for TLEs that are missing radio data
            for tle in tles {
                let found = arss.contains { ars in
                    ars.noradIndex == tle.noradIndex
                }
                if !found {
                    print("loadAll: missing radio: \(tle.noradIndex) \(tle.commonName)")
                }
            }
        }
    }
    
    /// Download and cache just radio data
    /// http://www.ne.jp/asahi/hamradio/je9pel/satslist.htm
    /// http://www.dk3wn.info/p/?page_id=29535
    static func loadRadioData() -> Promise<Void> {
        async {
            let url = URL(string: "https://www.ne.jp/asahi/hamradio/je9pel/satslist.csv")!
            let file = getDocumentsDirectory().appendingPathComponent("satslist.csv")
            let delimiter: Unicode.Scalar = ";"
            
            // Download file, ignoring failure
            try? await(downloadIfStale(url: url, to: file, minutes: 1))
            
            // Load data into cache from saved file
            arss.removeAll()
            let stream = InputStream(url: file)!
            let csv = try CSVReader(stream: stream, delimiter: delimiter)
            while let row = csv.next() {
                // Radio details from je9pel might have parse errors
                if let ars = try? ARS(fromJE9PEL: row) {
                    arss.append(ars)
                } else {
                    print("loadRadioData: warning, ignored \(row)")
                }
            }
            
            print("loadRadioData: loaded \(arss.count) ARSs")
        }
    }
    
    /// Download and cache just satellites
    /// https://celestrak.com/NORAD/elements/
    static func loadTLEs() -> Promise<Void> {
        return async {
            let url = URL(string: "https://celestrak.com/NORAD/elements/amateur.txt")!
            let file = getDocumentsDirectory().appendingPathComponent("amateur.txt")
            
            // Download file, ignoring failure
            try? await(downloadIfStale(url: url, to: file, minutes: 1))
            
            // Load data into cache from saved file
            tles.removeAll()
            let text: String = try String(contentsOf: file, encoding: .utf8)
            let lines = text.components(separatedBy: .newlines).filter { (s: String) -> Bool in s.count > 0 }
            for b in 0..<lines.count / 3 {
                let i = b * 3
                // TLEs from Celestrak will always parse
                // Error is not handled here so it will bubble up if any fail to parse
                let tle = try TLE(lines[i], lines[i+1], lines[i+2])
                tles.append(tle)
            }
            
            print("loadTLEs: loaded \(tles.count) TLEs")
        }
    }
    
    /// Download file only if existing file is older than a given limit
    static func downloadIfStale(url: URL, to: URL, minutes: Int) -> Promise<Void> {
        return async {
            let last = modificationDate(url: to)
            
            if last == nil || Date().minutes(from: last!) >= minutes {
                var req = URLRequest(url: url)
                req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                try await(URLSession.shared.downloadTask(.promise, with: req, to: to))
            }
        }
    }
    
    /// Last time file was modified/downloaded
    static func modificationDate(url: URL) -> Date? {
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: url.path)
            return attr[FileAttributeKey.modificationDate] as? Date
        } catch {
            return nil
        }
    };
    
    /// Get this app's documents directory
    static func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    enum E: Error {
        case unexpectedError
    }
}
