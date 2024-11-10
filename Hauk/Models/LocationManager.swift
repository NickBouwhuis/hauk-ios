import CoreLocation
import Foundation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var location: CLLocation?
    @Published var error: Error?
    
    private var locationManager: CLLocationManager?
    private var locationUpdateHandler: ((CLLocation) -> Void)?
    
    override init() {
        super.init()
        setup()
    }
    
    private func setup() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.pausesLocationUpdatesAutomatically = false
        
        authorizationStatus = locationManager?.authorizationStatus ?? .notDetermined
    }
    
    func requestAuthorization() {
        locationManager?.requestAlwaysAuthorization()
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
        
        locationManager?.startUpdatingLocation()
    }
    
    func stopUpdating() {
        locationManager?.stopUpdatingLocation()
        locationUpdateHandler = nil
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            
            // If we got authorization and should be updating, start updates
            if (manager.authorizationStatus == .authorizedAlways ||
                manager.authorizationStatus == .authorizedWhenInUse) &&
                self.locationUpdateHandler != nil {
                self.startUpdating()
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.location = location
            self.locationUpdateHandler?(location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = error
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