import Foundation
import SatelliteKit
import PromiseKit
import AwaitKit
import PMKFoundation
import CSV

/// Amateur radio satellite record from JE3PEL's list
struct JE3PEL {
    let name: String
    let noradIndex: Int
    let uplink: String
    let downlink: String
    let beacon: String
    let mode: String
    let callsign: String
    
    init(fromCSV row: [String]) throws {
        guard row.count == 8 else {
            throw JE3PELError.bad
        }
        
        guard row[7] == "active" else {
            throw JE3PELError.inactive
        }
        
        guard let number = Int(row[1]) else {
            throw JE3PELError.untrackable
        }
        
        name = row[0]
        noradIndex = number
        uplink = row[2]
        downlink = row[3]
        beacon = row[4]
        mode = row[5]
        callsign = row[6]
    }
    
    enum JE3PELError: Error {
        case bad
        case inactive
        case untrackable
    }
}

/// Everything an amateur radio operator can know about one object in Earth orbit
class AmateurRadioSatellite: Hashable {
    let tle: TLE
    let radios: [JE3PEL]
    var tracking: Bool = false
    
    private let sat: Satellite
    
    init(tle: TLE, radios: [JE3PEL]) {
        self.tle = tle
        self.radios = radios
        self.sat = Satellite(withTLE: tle)
    }
    
    /// Calculate next topocentric coordinates (south, east, up)
    func getTopo(date: Date, lat: Double, lon: Double) -> Vector {
        // Types expected by SatelliteKit
        let julian = date.julianDate
        let obs = LatLonAlt(lat: lat, lon: lon, alt: 0)
        
        // Run propagator
        let eci = sat.position(julianDays: julian)
        
        // Calc topocentric coords (x south, y east, z up)
        return eci2top(julianDays: julian, satCel: eci, obsLLA: obs)
    }
    
    //MARK: - Hashable
    
    static func == (lhs: AmateurRadioSatellite, rhs: AmateurRadioSatellite) -> Bool {
        return lhs.tle.noradIndex == rhs.tle.noradIndex
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(tle.noradIndex)
    }
}

/// Temporary global cache struct
/// TODO: replace this with data in views
struct Cache {
    
    /// The Cache
    static var list: [AmateurRadioSatellite] = []
    
    /// Download and cache both satellite and radio data
    static func loadAll() -> Promise<Void> {
        async {
            let tles = try await(loadTLEs())
            let radios = try await(loadRadioData())
            
            // Treat each TLE as unique satellite, find related radios or ignore
            // TODO: eventually return a fresh list instead of mutating static global
            list.removeAll()
            for tle in tles {
                let related = radios.filter { record in record.noradIndex == tle.noradIndex }
                if related.count > 0 {
                    list.append(AmateurRadioSatellite(tle: tle, radios: related))
                }
            }
            
            print("loadAll: prepared \(list.count) satellites")

            // Debug: Search for radios with missing orbital data
            var untrackable = 0
            for record in radios {
                if !tles.contains { tle in tle.noradIndex == record.noradIndex } {
                    untrackable += 1
                }
            }
            
            print("loadAll: unable to find \(untrackable) TLEs")
        }
    }
    
    /// Download and cache radio data
    /// Source: http://www.ne.jp/asahi/hamradio/je9pel/satslist.htm
    /// Other: http://www.dk3wn.info/p/?page_id=29535
    static func loadRadioData() -> Promise<[JE3PEL]> {
        async {
            let url = URL(string: "https://www.ne.jp/asahi/hamradio/je9pel/satslist.csv")!
            let file = getDocumentsDirectory().appendingPathComponent("satslist.csv")
            let delimiter: Unicode.Scalar = ";"
            
            // Download file, ignoring failure
            try? await(downloadIfStale(url: url, to: file, minutes: 1440))
            
            // Load data into cache from saved file
            let stream = InputStream(url: file)!
            let csv = try CSVReader(stream: stream, delimiter: delimiter)
            
            var batch: [JE3PEL] = []
            var ignored = 0
            while let row = csv.next() {
                // Ignore JE3PEL records that parse wrong, aren't active, or don't have NORAD ids
                if let ars = try? JE3PEL(fromCSV: row) {
                    batch.append(ars)
                } else {
                    ignored += 1
                }
            }
            
            print("loadRadioData: using \(batch.count) radio records")
            print("loadRadioData: ignored \(ignored) radio records")
            
            return batch
        }
    }
    
    /// Download and cache orbital elements
    /// NOTE: This source is missing 12 satellites denoted active on JE3PEL
    /// NOTE: I know that 2 are incorrectly marked as active, Space-Track has TLEs for 7 others, leaving 3 as "from caltech"???
    /// https://celestrak.com/NORAD/elements/
    static func loadTLEs() -> Promise<[TLE]> {
        return async {
            let url = URL(string: "https://celestrak.com/NORAD/elements/active.txt")!
            let file = getDocumentsDirectory().appendingPathComponent("active.txt")
            
            // Download file, ignoring failure
            try? await(downloadIfStale(url: url, to: file, minutes: 1440))
            
            // Load data into cache from saved file
            let text: String = try String(contentsOf: file, encoding: .utf8)
            let lines = text.components(separatedBy: .newlines).filter { (s: String) -> Bool in s.count > 0 }
            
            var batch: [TLE] = []
            for b in 0..<lines.count / 3 {
                let i = b * 3
                // TLEs from Celestrak will always parse
                // Error is not handled here so it will bubble up if any fail to parse
                batch.append(try TLE(lines[i], lines[i+1], lines[i+2]))
            }
            
            print("loadTLEs: loaded \(batch.count) TLEs")
            
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
