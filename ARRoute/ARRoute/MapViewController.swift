//  Created by Marc Le Moigne on 19/12/2019.
//  Copyright © 2019 Esri France. All rights reserved.
//

import UIKit
import ArcGIS

class MapViewController: UIViewController, AGSGeoViewTouchDelegate {

    @IBOutlet weak var toArButton: UIButton!
    @IBOutlet weak var mapView: AGSMapView!
    @IBOutlet weak var FromTextField: UITextField!
    @IBOutlet weak var ToTextField: UITextField!
    
    private var portal:AGSPortal!
    private var _map:AGSMap!
    private var _locationDisplay: AGSLocationDisplay!
    private var _graphicsOverlayFrom = AGSGraphicsOverlay()
    private var _graphicsOverlayTo = AGSGraphicsOverlay()
    private var _routeGraphicsOverlay = AGSGraphicsOverlay()
    private var _urlGeocoder:URL = URL(string: "YOUR_URL")!
    private var _urlRoute:URL = URL(string:"YOUR_URL")!
    private var _routeTask:AGSRouteTask!
    private var _routeParameters:AGSRouteParameters!
    private var _locatorTask:AGSLocatorTask!
    private var _reverseGeocodeParameters:AGSReverseGeocodeParameters!
    private var _cancelable: AGSCancelable!
    private var _pointFrom:AGSPoint!
    private var _pointTo:AGSPoint!
    
    
    public var mapToAr:MapToAr = MapToAr()
    
    var generatedRoute: AGSRoute! {
        didSet {
            let flag = generatedRoute != nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //first disable the go to Ar View button
        self.toArButton.isEnabled = false
        
        //validate licence and load map
        self._validateLicence()
    }
    
    //Function to validate licence
    private func _validateLicence(){
        
        //Create a View to push your credential and portal adress
        self.portal = AGSPortal(url: URL(string: "YOUR_PORTAL")!, loginRequired: false)
        self.portal.credential = AGSCredential(user: "USERNAME", password: "PASSWORD")
         self.portal.load() {[weak self] (error) in
            if let error = error {
                print(error)
                return
            }
                 // check the portal item loaded and print the modified date
            if self?.portal.loadStatus == AGSLoadStatus.loaded {
                let fullName = self?.portal.user?.fullName
                print(fullName!, " connected")
                        
                //load task & parameters of the geocoder
                self?._loadGeocode()
                //load task & parameters of the routing
                self?._loadRoute()
                //load the map
                self?._displayMap()
            }
        }
    }
    
    //Function to display a map, initialize LocationDisplay variable
    private func _displayMap() {
        //Display a map using the ArcGIS Online openStreetMap basemap service
        self._map = AGSMap(basemapType: .openStreetMap, latitude: 48.3833789, longitude: -4.4932725, levelOfDetail: 13)
        self.mapView.map = _map
        //for interaction with map
        self.mapView.touchDelegate = self
        
        //add graphic overlays
        self.mapView.graphicsOverlays.addObjects(from: [self._graphicsOverlayFrom, self._graphicsOverlayTo, self._routeGraphicsOverlay])
        
        //set location display
        self._locationDisplay = self.mapView.locationDisplay
    
        //When map loaded, display device location, handle change localation
        self._map.load{ [weak self] (error) in
            self?._showAndZoomDeviceLocation()
        }
    }
    
    //show Device postion
    private func _showAndZoomDeviceLocation() {
        //When location display start, pan and center map on my position
        self._locationDisplay.start{ _ in
            self._locationDisplay.autoPanMode = .compassNavigation
        }
    }
    

    private func _createGraphic(mapPoint:AGSPoint, direction:String) {
        let ptWGS84 = AGSGeometryEngine.projectGeometry(mapPoint, to: .wgs84()) as! AGSPoint
        
        if direction == "From"{
            
            //store mapPoint
            self._pointFrom = ptWGS84

            //remove all graphics from graphic layer
            self._graphicsOverlayFrom.graphics.removeAllObjects()
            
            //create and design symbol
            let image = UIImage(named:"arrow")!
            let symbol = AGSPictureMarkerSymbol(image: image)
            symbol.height = 25
            symbol.width = 25
            symbol.angle = Float(self._locationDisplay.heading)
            
            //create graphic
            let _graphicFrom = AGSGraphic(geometry: mapPoint, symbol: symbol, attributes: nil)
            
            //add graphic to graphic layer
            self._graphicsOverlayFrom.graphics.add(_graphicFrom)
        }
        else {
            //store mapPoint
            self._pointTo = ptWGS84
            
            //remove all graphics from graphic layer
            self._graphicsOverlayTo.graphics.removeAllObjects()
            
            //create and design symbol
            let symbol = AGSSimpleMarkerSymbol(style: .cross, color: .red, size: 25)
            
            //create graphic
            let _graphicTo = AGSGraphic(geometry: mapPoint, symbol: symbol, attributes: nil)
            
            //add graphic to graphic layer
            self._graphicsOverlayTo.graphics.add(_graphicTo)
        }
    }
    
    // Geocode part
    private func _loadGeocode(){
        //initialize locator task
        self._locatorTask = AGSLocatorTask(url: self._urlGeocoder)
        self._locatorTask.load { [weak self] (error) -> Void in
            if let error = error {
                print("Erreur : ", error)
                return
            }
            if (self?._locatorTask.loadStatus == .loaded) {
                self!._reverseGeocodeParameters = AGSReverseGeocodeParameters()
                self!._reverseGeocodeParameters.maxResults = 1
            }
        }
    }
    
    private func _reverseGeocode(point: AGSPoint, uiTextField: UITextField) {
        //cancel previous request
        if self._cancelable != nil {
            self._cancelable.cancel()
        }
        //normalize point
        let normalizedPoint = AGSGeometryEngine.normalizeCentralMeridian(of: point) as! AGSPoint
        self._cancelable = self._locatorTask.reverseGeocode(withLocation: normalizedPoint, parameters: self._reverseGeocodeParameters) { [weak self] (results: [AGSGeocodeResult]?, error: Error?) in
            if let error = error as NSError? {
                if error.code != NSUserCancelledError { //user canceled error
                    print(error)
                }
            } else if let result = results?.first {
                
                //add adress value to text field
                let addressString = result.attributes!["Address"] as? String ?? ""
                uiTextField.text = addressString
                return
            } else {
                uiTextField.text = "Adresse inconnue"
            }
        }
    }
    
    //Routing part
    private func _loadRoute() {
        //initialize route task
        self._routeTask = AGSRouteTask(url: self._urlRoute)
        self._routeTask.load { [weak self] (error) -> Void in
            if let error = error {
                print(error)
                return
            }
            if (self?._routeTask.loadStatus == .loaded) {
                //get default parameters
                self!._getDefaultParameters()
            }
        }
    }
    //method to get the default parameters for the route task
    private func _getDefaultParameters() {
        self._routeTask.defaultRouteParameters { [weak self] (params: AGSRouteParameters?, error: Error?) in
            if let error = error {
                print("Erreur : ", error)
            } else {
                //on completion store the parameters
                self?._routeParameters = params
                self?._routeParameters.returnDirections = true
                self?._routeParameters.returnRoutes = true
                self?._routeParameters.outputSpatialReference = self?.mapView.spatialReference
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        //if no route, alert user
        if self.generatedRoute == nil {
            let alert:UIAlertController =  UIAlertController(title: "Paramètres", message: "Paramètres manquants", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true)
        }
        else {
            if segue.identifier == "ShowArView"{
                
                //transfert AGS Points & route to AR View Controller
                guard let destination = segue.destination as? ARViewController else {return}
                self.mapToAr.ptFrom = self._pointFrom
                self.mapToAr.ptTo = self._pointTo
                self.mapToAr.route = self.generatedRoute.routeGeometry
                destination.mapToAr = self.mapToAr
            }
            else {
                return
            }
        }
    }
    
    @IBAction func goToArView(_ sender: UIButton) {
        self.performSegue(withIdentifier: "ShowArView", sender: self)
    }
    
    
    @IBAction func GetGPSLocation(_ sender: Any) {
        //get map point and project it to WGS 84
        guard let pt = self._locationDisplay.mapLocation else{return}
        let ptWGS84 = AGSGeometryEngine.projectGeometry(pt, to: .wgs84()) as! AGSPoint
        self._pointFrom = ptWGS84
        self._reverseGeocode(point: pt, uiTextField: self.FromTextField)
    }

    @IBAction func RunRouting(_ sender: Any) {
        //set parameters to return directions
        self._routeParameters.returnDirections = true
        
        //get info like distance or time travel
        let travelMode = self._routeTask.routeTaskInfo().travelModes.first
        self._routeParameters.travelMode = travelMode

        //clear previous routes
        self._routeGraphicsOverlay.graphics.removeAllObjects()
        
        //configure analysis parameters
        self._routeParameters.setStops([AGSStop(point: self._pointFrom), AGSStop(point: self._pointTo)])
        
        //run analysis
        self._routeTask.solveRoute(with: self._routeParameters) { (routeResult: AGSRouteResult?, error: Error?) in
            if let error = error {
                print("Erreur : ", error)
            } else if let route = routeResult?.routes.first {
                //show the resulting route on the map
                //also save a reference to the route object
                //in order to access directions
                self.generatedRoute = route
                let routeGraphic = AGSGraphic(geometry: self.generatedRoute.routeGeometry, symbol: self._routeSymbol(), attributes: nil)
                self._routeGraphicsOverlay.graphics.add(routeGraphic)
                
                //activate capability to go to AR View
                self.toArButton.isEnabled = true
            }
        }
    }
    
    //method provides a line symbol for the route graphic
    private func _routeSymbol() -> AGSSimpleLineSymbol {
        let symbol = AGSSimpleLineSymbol(style: .solid, color: .red, width: 5)
        return symbol
    }
    
    func geoView(_ geoView: AGSGeoView, didLongPressAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        self._createGraphic(mapPoint: mapPoint, direction: "To")
        self._reverseGeocode(point: mapPoint, uiTextField: self.ToTextField)
    }
    
    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        self._createGraphic(mapPoint: mapPoint, direction:"From")
        self._reverseGeocode(point: mapPoint, uiTextField: self.FromTextField)
    }
}

