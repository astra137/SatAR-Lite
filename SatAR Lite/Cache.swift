import Foundation
import SatelliteKit
import PromiseKit
import AwaitKit
import PMKFoundation
import CSV

/// Amateur radio satellite with ham radio frequencies and modes
struct ARS {
    let commonName: String
    let noradIndex: Int
    let uplink: String
    let downlink: String
    let beacon: String
    let mode: String
    let callsign: String
    
    init(fromJE9PEL row: [String]) throws {
        guard row.count == 8 else {
            throw ARSError.badJE9PEL
        }
        
        guard let number = Int(row[1]) else {
            throw ARSError.badJE9PEL
        }
        
        guard row[7] == "active" else {
            throw ARSError.inactiveJE9PEL
        }
        
        commonName = row[0]
        noradIndex = number
        uplink = row[2]
        downlink = row[3]
        beacon = row[4]
        mode = row[5]
        callsign = row[6]
    }
    
    enum ARSError: Error {
        case badJE9PEL
        case inactiveJE9PEL
    }
}

/// Temporary global cache struct
/// TODO: replace this with data in views
struct Cache {
    
    /// Cached satellite radio data
    static var sats: [ARS] = []
    
    /// Secret stash of orbital data
    private static var tles: [Int:TLE] = [:]
    
    /// Secret stash of propagators
    private static var satellites: [Int:Satellite] = [:]
    
    /// Create satellite and propagator if necessary
    private static func getSat(noradId: Int) -> Satellite {
        guard let sat = satellites[noradId] else {
            let tle = tles[noradId]!
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
            tles = try await(loadTLEs())
            let all = try await(loadRadioData())

            // Search for radios with missing orbital data
            for sat in all {
                if tles[sat.noradIndex] == nil {
                    print("loadAll: missing orbital data: \(sat.commonName) \(sat.noradIndex)")
                } else {
                    sats.append(sat)
                }
            }
        }
    }
    
    /// Download and cache radio data
    /// http://www.ne.jp/asahi/hamradio/je9pel/satslist.htm
    /// http://www.dk3wn.info/p/?page_id=29535
    static func loadRadioData() -> Promise<[ARS]> {
        async {
            let url = URL(string: "https://www.ne.jp/asahi/hamradio/je9pel/satslist.csv")!
            let file = getDocumentsDirectory().appendingPathComponent("satslist.csv")
            let delimiter: Unicode.Scalar = ";"
            
            // Download file, ignoring failure
            try? await(downloadIfStale(url: url, to: file, minutes: 1440))
            
            // Load data into cache from saved file
            var active: [ARS] = []
            var ignored = 0
            let stream = InputStream(url: file)!
            let csv = try CSVReader(stream: stream, delimiter: delimiter)
            while let row = csv.next() {
                // Radio details from je9pel might have parse errors
                if let ars = try? ARS(fromJE9PEL: row) {
                    active.append(ars)
                } else {
                    ignored += 1
                }
            }
            
            print("loadRadioData: using \(active.count) sats")
            print("loadRadioData: ignored \(ignored) sats")
            
            return active
        }
    }
    
    /// Download and cache orbital elements
    /// NOTE: This source is missing 12 satellites denoted active on JE3PEL
    /// NOTE: I know that 2 are incorrectly marked as active, Space-Track has TLEs for 7 others, leaving 3 as "from caltech"???
    /// https://celestrak.com/NORAD/elements/
    static func loadTLEs() -> Promise<[Int:TLE]> {
        return async {
            let url = URL(string: "https://celestrak.com/NORAD/elements/active.txt")!
            let file = getDocumentsDirectory().appendingPathComponent("active.txt")
            
            // Download file, ignoring failure
            try? await(downloadIfStale(url: url, to: file, minutes: 1440))
            
            // Load data into cache from saved file
            var batch: [Int:TLE] = [:]
            let text: String = try String(contentsOf: file, encoding: .utf8)
            let lines = text.components(separatedBy: .newlines).filter { (s: String) -> Bool in s.count > 0 }
            for b in 0..<lines.count / 3 {
                let i = b * 3
                // TLEs from Celestrak will always parse
                // Error is not handled here so it will bubble up if any fail to parse
                let tle = try TLE(lines[i], lines[i+1], lines[i+2])
                batch[tle.noradIndex] = tle
            }
            
            print("loadTLEs: loaded \(batch.count) tles")
            return batch
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
