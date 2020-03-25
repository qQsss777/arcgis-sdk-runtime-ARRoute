//  Created by Marc Le Moigne on 19/12/2019.
//  Copyright © 2019 Esri France. All rights reserved.
//

import UIKit
import ArcGIS

class ARViewController: UIViewController {

    private var _scene:AGSScene!
    private let _arView = ArcGISARView()
    private var _paramsSymbols:AGSSymbolStyleSearchParameters!
    private var _mobileStyle:AGSSymbolStyle!
    private var _graphicsOverlayFrom = AGSGraphicsOverlay()
    private var _graphicsOverlayTo = AGSGraphicsOverlay()
    private var _routeGraphicsOverlay = AGSGraphicsOverlay()
    private var _elevSurface:AGSSurface!
    
    public var mapToAr:MapToAr = MapToAr()


    override func viewDidLoad() {
        super.viewDidLoad()

        //add Ar View
        self._arView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self._arView)
        NSLayoutConstraint.activate([
            self._arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            self._arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            self._arView.topAnchor.constraint(equalTo: view.topAnchor),
            self._arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        
        //load Scene
        self.configureSceneForAR()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self._arView.startTracking(.ignore)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self._routeGraphicsOverlay.graphics.removeAllObjects()
        self._graphicsOverlayTo.graphics.removeAllObjects()
        self._graphicsOverlayFrom.graphics.removeAllObjects()
        self._arView.stopTracking()
    }
    
    private func configureSceneForAR() {
        self._scene = AGSScene()
        // add base surface for elevation data
        self._elevSurface = AGSSurface()
        /// The url of the Terrain 3D ArcGIS REST Service.
        let worldElevationServiceURL = URL(string: "YOUR_URL")!
        let elevationSource = AGSArcGISTiledElevationSource(url: worldElevationServiceURL)
        self._elevSurface.elevationSources.append(elevationSource)
        self._scene.baseSurface = self._elevSurface
        
        // Allow camera to go beneath the surface
        self._scene.baseSurface?.navigationConstraint = .stayAbove
        self._scene.baseSurface?.opacity = 0

        // Create Camera, altitude set to 0 so there is an error. We can call method on basesurface to get elevation point (not write here)
        let camera = AGSCamera(latitude: self.mapToAr.ptFrom!.y, longitude: self.mapToAr.ptFrom!.x, altitude: 0, heading: 0, pitch: 90, roll: 0.0)

        // Display the scene and configure arView
        //change worldAlignement to update heading with your value
        self._arView.sceneView.scene = self._scene
        self._arView.originCamera = camera
        self._arView.clippingDistance = 1000
        self._arView.translationFactor = 1
        
        // Configure atmosphere and space effect
        self._arView.sceneView.spaceEffect = .transparent
        self._arView.sceneView.atmosphereEffect = .none
        
        //when scene load
        self._scene.load { error in
           //add graphics overlays
           self._arView.sceneView.graphicsOverlays.addObjects(from: [self._graphicsOverlayFrom, self._graphicsOverlayTo, self._routeGraphicsOverlay])
            self._routeGraphicsOverlay.sceneProperties?.surfacePlacement = .drapedBillboarded
            self._graphicsOverlayTo.sceneProperties?.surfacePlacement = .drapedBillboarded
            self._graphicsOverlayFrom.sceneProperties?.surfacePlacement = .drapedBillboarded
            self._getSymbolStopsAndRoute()
        }
        
        self._elevSurface.elevationSources.first?.load { error in
            //update position with elevation source
            self._updateCamera(pt:self.mapToAr.ptFrom!)
        }
    }

    private func _updateCamera(pt:AGSPoint) {
        self._elevSurface.load{ error in
            self._elevSurface.elevation(for: pt) { results, error in
                if let error = error{
                    print("Altitude erreur : ", error)
                }
                //add 1 meters from elevation data
                let alti = results + 1
                let newCamera = AGSCamera(latitude: pt.y, longitude: pt.x, altitude: alti, heading: 0, pitch: 90, roll: 0.0)
                self._arView.originCamera = newCamera
            }
        }
    }
    
    private func _getSymbolStopsAndRoute (){
        //symbol start
        let symbolFrom:AGSSimpleMarkerSymbol = AGSSimpleMarkerSymbol(style: .circle, color: .red, size: 50)
        let graphicFrom:AGSGraphic = AGSGraphic(geometry: self.mapToAr.ptFrom, symbol: symbolFrom, attributes: nil)
        self._graphicsOverlayFrom.graphics.add(graphicFrom)
        
        //symbol finish
        let symbolTo:AGSSimpleMarkerSceneSymbol = AGSSimpleMarkerSceneSymbol(style: .diamond, color: .cyan, height: 2, width: 2, depth: 2, anchorPosition: .bottom)
        let graphicTo:AGSGraphic = AGSGraphic(geometry: self.mapToAr.ptTo, symbol: symbolTo, attributes: nil)
        self._graphicsOverlayTo.graphics.add(graphicTo)
        
        //route symbol
        let routeSymbol = AGSSimpleLineSymbol(style: .solid, color: .green, width: 2, markerStyle: .arrow, markerPlacement: .beginAndEnd)
        routeSymbol.antialias = true
        let routeGraphic = AGSGraphic(geometry: self.mapToAr.route , symbol: routeSymbol, attributes: nil)
        self._routeGraphicsOverlay.graphics.add(routeGraphic)
    }
}
