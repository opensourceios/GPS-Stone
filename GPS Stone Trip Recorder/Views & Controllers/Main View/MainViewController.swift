/*
 * MainViewController.swift
 * GPS Stone Trip Recorder
 *
 * Created by François Lamboley on 2019/6/16.
 * Copyright © 2019 Frost Land. All rights reserved.
 */

import Foundation
import UIKit



class MainViewController : UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
	
	@IBOutlet var pageControl: UIPageControl!
	
	@IBOutlet var buttonRecord: UIButton!
	@IBOutlet var buttonPause: UIButton!
	@IBOutlet var buttonListRecords: UIButton!
	@IBOutlet var buttonStop: UIButton!

	@IBOutlet var viewMiniInfos: UIView!
	@IBOutlet var labelMiniInfosDistance: UILabel!
	@IBOutlet var labelMiniInfosRecordTime: UILabel!
	@IBOutlet var labelMiniInfosRecordingState: UILabel!
	
	var pageViewController: UIPageViewController!
	
	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		fatalError("Unexpected init method")
	}
	
	required init?(coder: NSCoder) {
		viewControllers = [UIViewController?](repeating: nil, count: pageViewControllerIdentifiers.count)
		
		super.init(coder: coder)
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		
		let currentIdx = pageViewController.viewControllers?.first?.restorationIdentifier.flatMap{ pageViewControllerIdentifiers.firstIndex(of: $0) } ?? -1
		for i in 0..<viewControllers.count where i != currentIdx {
			viewControllers[i] = nil
		}
	}
	
	override var childForStatusBarStyle: UIViewController? {
		return pageViewController?.viewControllers?.first
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		switch segue.identifier {
		case "MainPageViewControllerSegue"?:
			pageViewController = (segue.destination as! UIPageViewController)
			pageViewController.dataSource = self
			pageViewController.delegate = self
			
			let viewController = viewControllers[0] ?? mainStoryboard.instantiateViewController(withIdentifier: pageViewControllerIdentifiers[0])
			pageViewController.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)
			viewControllers[0] = viewController
			setNeedsStatusBarAppearanceUpdate()
			
		default: (/*nop*/)
		}
	}
	
	/* ***************
	   MARK: - Actions
	   *************** */
	
	@IBAction func changePage(_ sender: UIPageControl) {
		let newIdx = pageControl.currentPage
		let oldIdx = pageViewController.viewControllers?.first?.restorationIdentifier.flatMap{ pageViewControllerIdentifiers.firstIndex(of: $0) } ?? -1
		
		let viewController = viewControllers[newIdx] ?? mainStoryboard.instantiateViewController(withIdentifier: pageViewControllerIdentifiers[newIdx])
		pageViewController.setViewControllers([viewController], direction: oldIdx < newIdx ? .forward : .reverse, animated: true, completion: nil)
		viewControllers[newIdx] = viewController
		setNeedsStatusBarAppearanceUpdate()
	}
	
	@IBAction func startRecording(_ sender: Any) {
	}
	
	@IBAction func pauseRecording(_ sender: Any) {
	}
	
	@IBAction func stopRecording(_ sender: Any) {
	}
	
	/* ***************************************************
	   MARK: - Page View Controller Data Source & Delegate
	   *************************************************** */
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
		guard let id = viewController.restorationIdentifier, let idx = pageViewControllerIdentifiers.firstIndex(of: id), idx > 0 else {return nil}
		return mainStoryboard.instantiateViewController(withIdentifier: pageViewControllerIdentifiers[idx-1])
	}
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		guard let id = viewController.restorationIdentifier, let idx = pageViewControllerIdentifiers.firstIndex(of: id), idx < pageViewControllerIdentifiers.count-1 else {return nil}
		return mainStoryboard.instantiateViewController(withIdentifier: pageViewControllerIdentifiers[idx+1])
	}
	
	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		/* Update the page control selected index */
		if let id = pageViewController.viewControllers?.first?.restorationIdentifier, let idx = pageViewControllerIdentifiers.firstIndex(of: id) {
			pageControl.currentPage = idx
		}
		
		setNeedsStatusBarAppearanceUpdate()
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
	private let pageViewControllerIdentifiers = ["VSOInfoViewController", "VSODetailsViewController", "VSOMapViewController"]
	
	private var viewControllers: [UIViewController?]
	
}