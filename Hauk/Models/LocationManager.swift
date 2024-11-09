import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private var locationUpdateHandler: ((CLLocation) -> Void)?
    
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var error: Error?
    
    override init() {
        authorizationStatus = .notDetermined
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .otherNavigation
        locationManager.distanceFilter = 10 // meters
        
        // Request authorization immediately on init
        requestAuthorization()
    }
    
    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func startUpdating(handler: ((CLLocation) -> Void)? = nil) {
        locationUpdateHandler = handler
        
        if authorizationStatus == .notDetermined {
            requestAuthorization()
            return
        }
        
        guard authorizationStatus == .authorizedAlways || 
              authorizationStatus == .authorizedWhenInUse else {
            error = LocationError.notAuthorized
            return
        }
        
        // Start location updates on main thread
        DispatchQueue.main.async { [weak self] in
            self?.locationManager.startUpdatingLocation()
        }
    }
    
    func stopUpdating() {
        // Stop updates on main thread
        DispatchQueue.main.async { [weak self] in
            self?.locationManager.stopUpdatingLocation()
            self?.locationUpdateHandler = nil
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = manager.authorizationStatus
            
            // If we got authorization and should be updating, start updates
            if (manager.authorizationStatus == .authorizedAlways ||
                manager.authorizationStatus == .authorizedWhenInUse) &&
                self?.locationUpdateHandler != nil {
                self?.startUpdating()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.location = location
            self?.locationUpdateHandler?(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.error = error
            print("Location manager error: \(error.localizedDescription)")
        }
    }
}

extension LocationManager {
    enum LocationError: LocalizedError {
        case notAuthorized
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Location access not authorized. Please enable location access in Settings."
            }
        }
    }
} 