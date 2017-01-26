//
//  DetectViewModel.swift
//  Heartbeat
//
//  Created by Com on 24/01/2017.
//  Copyright © 2017 Com. All rights reserved.
//

import UIKit
import AVFoundation


private enum SessionSetupResult {
	case success
	case notAuthorized
	case configurationFailed
}


class DetectViewModel: NSObject {
	
	var heartBeat = HeartBeatDetector()

	var preview: UIView?
	var defaultVideoDevice: AVCaptureDevice?
	var videoDeviceInput: AVCaptureDeviceInput!
	lazy var previewLayer: AVCaptureVideoPreviewLayer = {
		let preview =  AVCaptureVideoPreviewLayer(session: self.session)
		preview?.videoGravity = AVLayerVideoGravityResizeAspectFill
		if self.preview != nil {
			preview?.frame = (self.preview?.bounds)!
		}
		return preview!
	}()
	
	let session = AVCaptureSession()
	let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil)
	fileprivate var setupResult: SessionSetupResult = .success
	
	var cameraErrorHandler: ((String) ->())?
	
	var duration = 10
	var fps = 10
	
	
	// MARK: init methods
	
	func initCamera(with view: UIView, seconds: Int = 10, dectionPerSecond: Int = 30) {
		preview = view
		
		duration = seconds
		fps = dectionPerSecond
		
		heartBeat.duration = duration
		heartBeat.fps = fps
		
		switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
		case .authorized:
			break
			
		default:
			setupResult = .notAuthorized
		}
		
		sessionQueue.async { [unowned self] in
			self.configureSession()
		}
	}
	
	
	func startCamera() {
		self.heartBeat.reset()
		
		sessionQueue.async {
			switch self.setupResult {
			case .success:
				// set input device configuration for flash
				try? self.defaultVideoDevice?.lockForConfiguration()
				self.defaultVideoDevice?.torchMode = .on
				self.defaultVideoDevice?.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(self.fps))
				self.defaultVideoDevice?.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(self.fps))
				self.defaultVideoDevice?.unlockForConfiguration()
				
				self.session.startRunning()
				
			default:
				DispatchQueue.main.async { [unowned self] in
					guard self.cameraErrorHandler != nil else { return }
					self.cameraErrorHandler?("Camera configuration error")
				}
			}
		}
	}
	
	
	func stopCamera() {
		if self.session.isRunning == true {
			self.session.stopRunning()
		}
	}
	
	
	deinit {
		sessionQueue.async { [unowned self] in
			if self.setupResult == .success {
				self.session.stopRunning()
			}
		}
	}
	
	
	// MARK: camera configuration
	
	func configureSession() {
		guard setupResult == .success else { return }
		
		session.beginConfiguration()
		
		session.sessionPreset = AVCaptureSessionPresetLow
		
		let errorHandler: ((String) -> ()) = { [weak self] errMsg in
			print("Could not add video device input to the session")
			self?.setupResult = .configurationFailed
			self?.session.commitConfiguration()
			return
		}
		
		do {
			// find camera device
			if let dualCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInDuoCamera, mediaType: AVMediaTypeVideo, position: .back) {
				defaultVideoDevice = dualCameraDevice
			} else if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back) {
				defaultVideoDevice = backCameraDevice
			} else if let frontCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front) {
				defaultVideoDevice = frontCameraDevice
			}
			
			// add input device
			let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice)
			if !session.canAddInput(videoDeviceInput) {
				errorHandler("Could not add video device input to the session");
			}
			
			session.addInput(videoDeviceInput)
			self.videoDeviceInput = videoDeviceInput
			
			/*DispatchQueue.main.async {
				self.preview?.layer.addSublayer(self.previewLayer)
			}*/
			
			// add output device
			let videoDeviceOutput = AVCaptureVideoDataOutput()
			videoDeviceOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: kCVPixelFormatType_32BGRA]
			videoDeviceOutput.alwaysDiscardsLateVideoFrames = true
			
			let queue = DispatchQueue(label: "com.invasivecode.videoQueue")
			videoDeviceOutput.setSampleBufferDelegate(self, queue: queue)
			
			if !session.canAddOutput(videoDeviceOutput) {
				errorHandler("Could not add video device output to the session")
			}
			session.addOutput(videoDeviceOutput)
			
		} catch {
			errorHandler("Exception error")
		}
		
		session.commitConfiguration()
	}
}


// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension DetectViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
	
	public func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
		let cvImg = CMSampleBufferGetImageBuffer(sampleBuffer)
		
		CVPixelBufferLockBaseAddress(cvImg!, CVPixelBufferLockFlags(rawValue: 0))
		
		heartBeat.detectHeartbeat(from: cvImg!)
		
		CVPixelBufferUnlockBaseAddress(cvImg!, CVPixelBufferLockFlags(rawValue: 0))
	}
	
}
