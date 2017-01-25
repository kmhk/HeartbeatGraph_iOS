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
	
	
	// MARK: life-cycle methods
    override func viewDidLoad() {
        super.viewDidLoad()

		viewModel.cameraErrorHandler = { [weak self] errorMsg in
			let alert = UIAlertController(title: "", message: errorMsg, preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
			self?.show(alert, sender: nil)
		}
		viewModel.initCamera(with: viewCamera, seconds: 10, dectionPerSecond: 30)
		viewModel.heartBeat.delegate = self
		
		viewCamera.layer.cornerRadius = viewCamera.frame.size.width / 2
		viewCamera.layer.borderWidth = 1.0
		viewCamera.clipsToBounds = true
    }
	
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		viewModel.startCamera()
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
	}
	
	
	func heartBeatUpdate(_ bpm: Int, atTime: Int) {
		lblBpm.text = "\(bpm)" + " bpm"
		lblTime.text = "\(atTime)" + "ms"
	}
	
	
	func heartBeatFinished() {
		viewModel.stopCamera()
		
		btnDetect.isHidden = false
		lblNote.text = "Detection finished. Click \"New Detect\" for new detection"
	}
	
	
	func heartBeatDetectInterrupt() {
		lblNote.text = "Please cover the back-camera and the flash with your finger!"
	}
}
