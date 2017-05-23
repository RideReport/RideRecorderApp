//
//  RouteManagerTests.swift
//  Ride
//
//  Created by William Henderson on 5/17/17.
//  Copyright © 2017 Knock Softwae, Inc. All rights reserved.
//

import XCTest
import CoreData
import CoreMotion

class RouteManagerTests: XCTestCase, NSFetchedResultsControllerDelegate {
    private var fetchedResultsController : NSFetchedResultsController<NSFetchRequestResult>!
    private var didChangeObjectHandler: ((NSFetchedResultsChangeType, Trip?)->())?

    override func setUp() {
        super.setUp()
        
        CoreDataManager.startup(true)
        SensorManagerComponent.inject(motionManager: CMMotionManager(),
                                       motionActivityManager: CMMotionActivityManager(),
                                       locationManager: LocationManager(type: .gpx),
                                       routeManager: RouteManager(),
                                       randomForestManager: RandomForestManager(),
                                       classificationManager: TestClassificationManager())
        SensorManagerComponent.shared.randomForestManager.startup()
        SensorManagerComponent.shared.classificationManager.startup()
        
        let cacheName = "RouteManageTestsFetchedResultsController"
        let context = CoreDataManager.shared.currentManagedObjectContext()
        NSFetchedResultsController<NSFetchRequestResult>.deleteCache(withName: cacheName)
        let fetchedRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Trip")
        fetchedRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest:fetchedRequest , managedObjectContext: context, sectionNameKeyPath: nil, cacheName:cacheName )
        self.fetchedResultsController.delegate = self
        do {
            try self.fetchedResultsController.performFetch()
        } catch let error {
            DDLogError("Error loading trips view fetchedResultsController \(error as NSError), \((error as NSError).userInfo)")
            abort()
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testRouteManagerStartsTrip() {
        let predictionTemplate = ActivityTypePrediction(activityType: .cycling, confidence: 1.0, sensorDataCollection: nil)
        
        let expectation = self.expectation(description: "NewTripCreated")

        SensorManagerComponent.shared.locationManager.setLocations(locations: GpxLocationGenerator.generate())
        SensorManagerComponent.shared.classificationManager.setTestPredictionsTemplates(testPredictions: [predictionTemplate])

        self.didChangeObjectHandler = { (type, trip) in
            if let newTrip = trip, !newTrip.isClosed, type == .insert {
                expectation.fulfill()
            }
        }
        SensorManagerComponent.shared.routeManager.startup(true)
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if let handler = didChangeObjectHandler { handler(type, anObject as? Trip) }
    }
    
}
