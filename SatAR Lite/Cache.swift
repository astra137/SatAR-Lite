import Foundation
import SatelliteKit

struct Cache {
    
    /// Cached global instances
    static var noradIds: [Int] = []
    static var tles: [Int:TLE] = [:]
    static var satellites: [Int:Satellite] = [:]
    
    /// Create satellite and propagator if necessary
    static func getSat(noradId: Int) -> Satellite {
        guard let sat = satellites[noradId] else {
            let sat = Satellite(withTLE: tles[noradId]!)
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
        return eci2top_fixed(julianDays: julian, satVector: eci, geoVector: obs)
    }

    /// Downloads, caches, and loads all TLEs as Satellites
    static func loadAll(completionBlock: @escaping (Error?) -> Void) {
        let url = URL(string: "https://celestrak.com/NORAD/elements/amateur.txt")!
        let file = getDocumentsDirectory().appendingPathComponent("amateur.txt")
        
        downloadIfStale(url: url, file: file, age: 12) { (error: Error?) in
            // Report download error, but don't stop loading from file
            if let error = error {
                print(error)
            }
            
            do {
                let text: String = try String(contentsOf: file, encoding: .utf8)
                let lines = text.components(separatedBy: .newlines).filter { (s: String) -> Bool in s.count > 0 }
                
                for b in 0..<lines.count / 3 {
                    let i = b * 3
                    let tle = try TLE(lines[i], lines[i+1], lines[i+2])
                    noradIds.append(tle.noradIndex)
                    tles[tle.noradIndex] = tle
                }
                
                completionBlock(nil)
            } catch {
                completionBlock(error)
            }
        }
    }
    
    /// Download file only if existing file age in hours to too old
    static func downloadIfStale(url: URL, file: URL, age: Int, completionBlock: @escaping (Error?) -> Void) {
        let last = modificationDate(url: file)

        if last == nil || Date().hours(from: last!) >= age {
            download(url: url, file: file, completionBlock: completionBlock)
        } else {
            completionBlock(nil)
        }
    }
    
    ///
    static func download(url: URL, file: URL, completionBlock: @escaping (Error?) -> Void) {
        print("Beginning download")
        print(url)
        print(file)
        
        URLSession.shared.downloadTask(with: url, completionHandler: { (location, response, error) in
            guard
                let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
                let location = location, error == nil
                else { return completionBlock(error) }

            do {
                try? FileManager.default.removeItem(atPath: file.path)
                try FileManager.default.moveItem(at: location, to: file)
                completionBlock(nil)
            } catch {
                completionBlock(error)
            }
        }).resume()
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
}


/// TODO: remove this fixed version once the PR is accepted
func eci2top_fixed(julianDays: Double, satVector: Vector, geoVector: LatLonAlt) -> Vector {
    let     latitudeRads = geoVector.lat * deg2rad
    let     sinLatitude = sin(latitudeRads)
    let     cosLatitude = cos(latitudeRads)
    
    let obsVector = geo2eci(julianDays: julianDays, geodetic: geoVector)
    let obs2sat = satVector - obsVector
    
    let     siderealRads = siteMeanSiderealTime(julianDate: julianDays, geoVector.lon) * deg2rad
    let     sinSidereal = sin(siderealRads)
    let     cosSidereal = cos(siderealRads)
    
    let topS = +sinLatitude * cosSidereal * obs2sat.x +
        sinLatitude * sinSidereal * obs2sat.y -
        cosLatitude * obs2sat.z
    
    let topE = -sinSidereal * obs2sat.x +
        cosSidereal * obs2sat.y
    
    let topZ = +cosLatitude * cosSidereal * obs2sat.x +
        cosLatitude * sinSidereal * obs2sat.y +
        sinLatitude * obs2sat.z
    
    return Vector(topS, topE, topZ)
}
