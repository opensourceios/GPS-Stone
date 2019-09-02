/*
 * MapViewController.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/6/19.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import CoreData
import Foundation
import MapKit
import os.log
import UIKit

import KVObserver
import RetryingOperation



class MapViewController : UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
	
	@IBOutlet var buttonCenterMapOnCurLoc: UIButton!
	@IBOutlet var mapView: MKMapView!
	@IBOutlet var viewStatusBarBlur: UIView!
	
	var boundingMapRect: MKMapRect = .null
	var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .default
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		_ = kvObserver.observe(object: locationRecorder, keyPath: #keyPath(LocationRecorder.objc_status), kvoOptions: [.initial], dispatchType: .asyncOnMainQueueDirectInitial, handler: { [weak self] _ in
			guard let self = self else {return}
			self.currentRecording = self.locationRecorder.status.recordingRef.flatMap{ self.recordingsManager.unsafeRecording(from: $0) }
		})
	}
	
	func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
		assert(overlay is MKPolyline)
		return MKPolylineRenderer(overlay: overlay)
	}
	
	/* *******************************************
	   MARK: - Fetched Results Controller Delegate
	   ******************************************* */
	
	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		/* Note: We could use the controller did change section/object methods,
		 *       however, I don’t think we’d gain _anything at all_ in terms of
		 *       performance, so let’s just do this instead (which avoids having
		 *       to create non-trivial alorithms to reconcile the cache with the
		 *       change notification we’d get from the controller). */
		assert(controller === pointsFetchResultsController)
		let op = ProcessPointsOperation(fetchedResultsController: pointsFetchResultsController!, polylinesCache: polylinesCache)
		op.completionBlock = { [weak self] in self?.processPendingPolylines() }
		pointsProcessingQueue.addOperation(op)
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let c = S.sp.constants
	private let locationRecorder = S.sp.locationRecorder
	private let recordingsManager = S.sp.recordingsManager
	
	private let pointsProcessingQueue: OperationQueue = {
		let ret = OperationQueue()
		ret.name = "Points Processing Queue"
		ret.maxConcurrentOperationCount = 1
		return ret
	}()
	
	private let kvObserver = KVObserver()
	private var pointsFetchResultsController: NSFetchedResultsController<RecordingPoint>?
	
	private var polylinesCache = PolylinesCache()
	
	private var currentRecording: Recording? {
		willSet {
			pointsFetchResultsController?.delegate = nil
			pointsFetchResultsController = nil
			
			pointsProcessingQueue.cancelAllOperations()
			mapView.removeOverlays(mapView.overlays)
			polylinesCache = PolylinesCache()
		}
		didSet  {
			guard let r = currentRecording, let c = r.managedObjectContext else {return}
			
			let fetchRequest: NSFetchRequest<RecordingPoint> = RecordingPoint.fetchRequest()
			fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(RecordingPoint.recording), r)
			fetchRequest.sortDescriptors = [
				NSSortDescriptor(keyPath: \RecordingPoint.segmentId, ascending: true),
				NSSortDescriptor(keyPath: \RecordingPoint.date, ascending: true)
			]
			let ctrl = NSFetchedResultsController<RecordingPoint>(
				fetchRequest: fetchRequest, managedObjectContext: c,
				sectionNameKeyPath: #keyPath(RecordingPoint.segmentId),
				cacheName: r.objectID.uriRepresentation().absoluteString
			)
			
			do {
				try ctrl.performFetch()
				
				let op = ProcessPointsOperation(fetchedResultsController: ctrl, polylinesCache: polylinesCache)
				op.completionBlock = { [weak self] in self?.processPendingPolylines() }
				pointsProcessingQueue.addOperation(op)
				
				pointsFetchResultsController = ctrl
				ctrl.delegate = self
			} catch {
				/* We do nothing in case of an error. The map will simply never be updated… */
			}
		}
	}
	
	private func processPendingPolylines() {
		
	}
	
}

fileprivate class PolylinesCache {
	
	var numberOfSections = 0
	
	/* The number of points currently added in the cache for a given section. */
	var nPointsBySection = [Int]()
	/* We break down each section to polylines of 100 points in order to avoid
	 * having to redraw the whole path each time a new point is added. This is
	 * why polylinesBySection is an array of array of polylines instead of a
	 * simple array of polylines. */
	var polylinesBySection = [[MKPolyline]]()
	/* Between each sections we show a dotted line indicating missing information
	 * (the recording was paused). This variable contains these polylines. They
	 * optional because some section might not have any points in them, in which
	 * case there are no dotted line to show, but we must still have an element
	 * in the array to have the correct count of objects in the array. */
	var interSectionPolylines = [MKPolyline?]()
	
	var polylinesToRemoveFromMap = [MKPolyline]()
	var plainPolylinesToAddToMap = [MKPolyline]()
	var dottedPolylinesToAddToMap = [MKPolyline]()
	
}

/* Note: We overwrite RetryingOperation instead of Operation mainly because I
 * have taken the habit of doing so, but in this case overwriting `main` in a
 * standard Operation would have been fine… */
fileprivate class ProcessPointsOperation : RetryingOperation {
	
	var polylinesCache: PolylinesCache
	let pointsToProcess: [[CLLocationCoordinate2D]]
	
	init(fetchedResultsController: NSFetchedResultsController<RecordingPoint>, polylinesCache pc: PolylinesCache) {
		assert(Thread.isMainThread)
		
		polylinesCache = pc
		guard let sections = fetchedResultsController.sections else {
			pointsToProcess = []
			return
		}
		
		var pointsToProcessBuilding = [[CLLocationCoordinate2D]]()
		for i in max(pc.numberOfSections-1, 0)..<sections.count {
			let section = sections[i]
			guard let points = section.objects as! [RecordingPoint]? else {
				pointsToProcessBuilding.append([])
				continue
			}
			if pc.numberOfSections > i {pointsToProcessBuilding.append(points[pc.nPointsBySection[i]..<points.count].map{ $0.location!.coordinate })}
			else                       {pointsToProcessBuilding.append(                                       points.map{ $0.location!.coordinate })}
		}
		pointsToProcess = pointsToProcessBuilding
	}
	
	override var isAsynchronous: Bool {
		return false
	}
	
	override func startBaseOperation(isRetry: Bool) {
		let startSectionIndex = max(polylinesCache.numberOfSections-1, 0)
		
		for (sectionDelta, pointsInSection) in pointsToProcess.enumerated() {
			let sectionIndex = startSectionIndex + sectionDelta
			assert(sectionIndex <= polylinesCache.numberOfSections)
			
			/* Add a section in the cache if needed */
			if sectionIndex == polylinesCache.numberOfSections {
				polylinesCache.numberOfSections += 1
				polylinesCache.nPointsBySection.append(0)
				polylinesCache.polylinesBySection.append([])
				if sectionDelta+1 < pointsInSection.count {
					if let p1 = pointsInSection.first, let p2 = pointsToProcess[sectionDelta+1].first {
						let l = MKPolyline(coordinates: [p1, p2], count: 2)
						polylinesCache.interSectionPolylines.append(l)
						polylinesCache.dottedPolylinesToAddToMap.append(l)
					} else {
						polylinesCache.interSectionPolylines.append(nil)
					}
				}
			}
			
			/* Add the new points in the current section */
			let latestPolylineOfSection = polylinesCache.polylinesBySection[sectionIndex].last
			
		}
		
		baseOperationEnded()
	}
	
}
