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
	
	
	func exportXML(with points:[Any], size: CGSize) -> URL { // points is array of pair of beathears & time, size is content size
		let docPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
		let filePath = URL(fileURLWithPath: docPath!).appendingPathComponent("graph"+Date().description+".svg")
		print(filePath.absoluteString)
		
		let xmlWriter = XMLWriter()
		xmlWriter.setPrettyPrinting("\t", withLineBreak: "\n")
		
		xmlWriter.writeStartDocument(withEncodingAndVersion: "UTF-8", version: "1.0")
		
		xmlWriter.writeStartElement("svg")
		xmlWriter.writeAttribute("xmlns", value: "http://www.w3.org/2000/svg")
		xmlWriter.writeAttribute("version", value: "1.0")
		xmlWriter.writeAttribute("width", value: "\(size.width)px")
		xmlWriter.writeAttribute("height", value: "\(size.height)px")
		xmlWriter.writeAttribute("viewBox", value: "0 0 \(size.width) \(size.height)")
		
		drawAxisElementToXML(with: size, points: points, xmlWriter: xmlWriter)
		
		xmlWriter.writeEndElement()
		xmlWriter.writeEndDocument()
		
		let xmlString = xmlWriter.toString() as String
		try? xmlString.write(to: filePath, atomically: true, encoding: .utf8)
		
		return filePath
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
	
	
	// MARK: - Write XML Element for SVG format
	
	func drawAxisElementToXML(with size:CGSize, points: [Any], xmlWriter: XMLWriter) {
		// draw xaxis
		drawLineToXML(with: xmlWriter, x1: 0, y1: Int(size.height-40), x2: Int(size.width), y2: Int(size.height-40), color: "black")
		
		var o: CGFloat = 40
		while o <= size.width {
			o = o + xUnit
			
			var len: CGFloat = 5
			if (Int(o - 40) % (Int(xUnit) * 30)) == 0 {
				len = 20
				
				let text = "\(Int(o - 40) / (Int(xUnit) * 30))s"
				drawTextToXML(with: xmlWriter, x: Int(o-5), y: Int(size.height-25+len), text: text, color: "blue")
			}
			
			drawLineToXML(with: xmlWriter, x1: Int(o), y1: Int(size.height-40), x2: Int(o), y2: Int(size.height-40+len), color: "black")
		}
		
		// draw y axix
		drawLineToXML(with: xmlWriter, x1: 40, y1: Int(size.height), x2: 40, y2: 0, color: "black")
		
		var yUnit = (size.height - 40) / 24
		o = size.height - 40 - yUnit
		var strUnit = 10
		while o > 0 {
			drawLineToXML(with: xmlWriter, x1: 30, y1: Int(o), x2: 40, y2: Int(o), color: "black")
			
			let text = "\(strUnit)"
			drawTextToXML(with: xmlWriter, x: 10, y: Int(o+5), text: text, color: "green")
			
			o = o - yUnit
			strUnit = strUnit + 10
		}
		
		drawTextToXML(with: xmlWriter, x: 5, y: Int(size.height - 30), text: "BPM", color: "green")
		drawLineToXML(with: xmlWriter, x1: 40, y1: Int(size.height-40), x2: 0, y2: Int(size.height), color: "black")
		drawTextToXML(with: xmlWriter, x: 14, y: Int(size.height - 6), text: "TIME", color: "blue")
		
		// draw graph
		yUnit = yUnit / 10
		for i in 1 ..< points.count {
			let pt1 = points[i-1] as! DrawPoint
			let x1: CGFloat = 40 + xUnit * CGFloat(i-1)
			let y1: CGFloat = (size.height - 40) - (yUnit * CGFloat(pt1.bpm))
			
			let pt2 = points[i] as! DrawPoint
			let x2: CGFloat = 40 + xUnit * CGFloat(i)
			let y2: CGFloat = (size.height - 40) - (yUnit * CGFloat(pt2.bpm))
			
			drawLineToXML(with: xmlWriter, x1: Int(x1), y1: Int(y1), x2: Int(x2), y2: Int(y2), color: "red")
		}
	}
	
	
	func drawLineToXML(with xmlWriter: XMLWriter, x1: Int, y1: Int, x2: Int, y2: Int, color: String, border: Int = 1) {
		xmlWriter.writeStartElement("line")
		
		xmlWriter.writeAttribute("x1", value: "\(x1)")
		xmlWriter.writeAttribute("y1", value: "\(y1)")
		xmlWriter.writeAttribute("x2", value: "\(x2)")
		xmlWriter.writeAttribute("y2", value: "\(y2)")
		xmlWriter.writeAttribute("stroke", value: color)
		xmlWriter.writeAttribute("stroke-width", value: "\(border)")
		
		xmlWriter.writeEndElement()
	}
	
	
	func drawTextToXML(with xmlWriter: XMLWriter, x: Int, y: Int, text: String, color: String,
	                   fontFamily: String = "HelveticaNeue-Bold, Helvetica Neue", fontSize: Int = 10) {
		xmlWriter.writeStartElement("text")
		xmlWriter.writeAttribute("fill", value: color)
		xmlWriter.writeAttribute("font-family", value: fontFamily)
		xmlWriter.writeAttribute("font-size", value: "\(fontSize)")
		
		xmlWriter.writeStartElement("tspan")
		xmlWriter.writeAttribute("x", value: "\(x)")
		xmlWriter.writeAttribute("y", value: "\(y)")
		xmlWriter.writeAttribute("fill", value: color)
		xmlWriter.writeCharacters(text)
		xmlWriter.writeEndElement()
		
		xmlWriter.writeEndElement()
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
