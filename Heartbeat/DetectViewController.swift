//
//  DetectViewController.swift
//  Heartbeat
//
//  Created by Com on 24/01/2017.
//  Copyright © 2017 Com. All rights reserved.
//

import UIKit
import AVFoundation

class DetectViewController: UIViewController {
	
	var viewModel = DetectViewModel()

	@IBOutlet weak var viewCamera: UIView!
	@IBOutlet weak var btnDetect: UIButton!
	@IBOutlet weak var lblNote: UILabel!
	@IBOutlet weak var lblBpm: UILabel!
	@IBOutlet weak var lblTime: UILabel!
	@IBOutlet weak var scrollContainer: UIScrollView!
	
	var viewGraph: HeartbeatGraphView?
	
	
	// MARK: life-cycle methods
    override func viewDidLoad() {
        super.viewDidLoad()

		viewModel.cameraErrorHandler = { [weak self] errorMsg in
			let alert = UIAlertController(title: "", message: errorMsg, preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
			self?.show(alert, sender: nil)
		}
		viewModel.initCamera(with: viewCamera, seconds: 10)
		viewModel.heartBeat.delegate = self
		
		viewCamera.layer.cornerRadius = viewCamera.frame.size.width / 2
		viewCamera.layer.borderWidth = 1.0
		viewCamera.clipsToBounds = true
		
		viewGraph = HeartbeatGraphView(frame: scrollContainer.frame)
		scrollContainer.addSubview(viewGraph!)
    }
	
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		viewModel.startCamera()
	}
	
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		viewGraph?.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: scrollContainer.frame.size)
	}

	
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		
		if let videoPreviewLayerConnection = (viewCamera.layer as! AVCaptureVideoPreviewLayer).connection {
			videoPreviewLayerConnection.videoOrientation = .portrait
		}
	}
	
	
	@IBAction func newDetectBtnTap(_ sender: Any) {
		viewModel.startCamera()
		
		lblNote.text = "Please cover the back-camera and the flash with your finger!"
		btnDetect.isHidden = true
	}
}


// MARK: - HeartBeatDetectorDelegate

extension DetectViewController: HeartBeatDetectorDelegate {
	
	func heartBeatStarted() {
		lblNote.text = "Detecting now... Please keep your finger for 10s"
		
		viewGraph?.reset()
		viewGraph?.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: scrollContainer.frame.size)
		scrollContainer.contentSize = CGSize(width: (viewGraph?.frame.size.width)!, height: (viewGraph?.frame.size.height)!)
	}
	
	
	func heartBeatUpdate(_ bpm: Int, atTime: Int) {
		lblBpm.text = "\(bpm)" + " bpm"
		lblTime.text = "\(atTime)" + "ms"
		
		viewGraph?.drawGraph(with: bpm, time: atTime)
		
		scrollContainer.contentSize = CGSize(width: (viewGraph?.frame.size.width)!, height: (viewGraph?.frame.size.height)!)
		scrollContainer.setContentOffset(CGPoint(x: (viewGraph?.frame.size.width)! - scrollContainer.frame.size.width, y: 0), animated: true)
	}
	
	
	func heartBeatFinished() {
		viewModel.stopCamera()
		
		btnDetect.isHidden = false
		lblNote.text = "Detection finished. Click \"New Detect\" for new detection, \(viewGraph?.points.count)"
	}
	
	
	func heartBeatDetectInterrupt() {
		lblNote.text = "Please cover the back-camera and the flash with your finger!"
	}
}
