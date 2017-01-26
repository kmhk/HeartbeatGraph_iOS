//
//  HeartBeatDetector.swift
//  Heartbeat
//
//  Created by Com on 24/01/2017.
//  Copyright © 2017 Com. All rights reserved.
//

import UIKit

// MARK: -
protocol HeartBeatDetectorDelegate {
	func heartBeatStarted()
	func heartBeatUpdate(_ bpm: Int, atTime: Int)
	func heartBeatFinished()
	func heartBeatDetectInterrupt()
}


// MARK: -
class HeartBeatDetector: NSObject {
	
	var delegate: HeartBeatDetectorDelegate?
	
	var duration = 10 // detection seconds, now detecting heartbeat for 10 s
	var fps = 10 // detection counts per seconds, now it is detecting heartbeat in every 100 ms
	var hueArray = [CGFloat]()
	
	var isDetecting: Bool = false {
		willSet(newValue) {
			if !isDetecting && newValue && delegate != nil {
				DispatchQueue.main.async {
					self.delegate?.heartBeatStarted()
				}
			} else if isDetecting && !newValue && delegate != nil {
				DispatchQueue.main.async {
					self.delegate?.heartBeatDetectInterrupt()
				}
			}
		}
	}
	
	var matrixCount = 9
	var xv: [CGFloat]
	var yv: [CGFloat]
	
	
	// MARK: initialize methods
	
	override init() {
		xv = [CGFloat](repeating: 0.0, count: matrixCount)
		yv = [CGFloat](repeating: 0.0, count: matrixCount)
		
		super.init()
	}
	
	
	func detectHeartbeat(from cvImg: CVImageBuffer) {
		// detect average color if it is possible to detect
		let w = CVPixelBufferGetWidth(cvImg)
		let h = CVPixelBufferGetHeight(cvImg)
		
		let buf = CVPixelBufferGetBaseAddress(cvImg)?.assumingMemoryBound(to: UInt8.self)
		let i8array = Array(UnsafeBufferPointer(start: buf, count: w * h))
		
		var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
		for y in 0 ..< (h) {
			for x in 0 ..< (w/4) {
				let index = y*(w/4)+(x*4)
				b = b + CGFloat(i8array[index])
				g = g + CGFloat(i8array[index+1])
				r = r + CGFloat(i8array[index+2])
			}
		}
		
		r = r / CGFloat(w * h / 4)
		g = g / CGFloat(w * h / 4)
		b = b / CGFloat(w * h / 4)
		
		guard r >= 170 && g <= 10 && b <= 50 else { // not available to detect heartbeat
			hueArray.removeAll()
			isDetecting = false
			return
		}
		
		// starting detection
		isDetecting = true
		
		calcBrightness(with: UIColor(red: r/255.0, green: g/255.0, blue: b/255.0, alpha: 1.0))
	}
	
	
	func reset() {
		hueArray.removeAll()
		xv = [CGFloat](repeating: 0.0, count: matrixCount)
		yv = [CGFloat](repeating: 0.0, count: matrixCount)
		isDetecting = false
	}
	
	
	func calcBrightness(with averageColor: UIColor) {
		var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
		averageColor.getHue(&h, saturation: &s, brightness: &b, alpha: &alpha)
		
		hueArray.append(h)
		
		guard delegate != nil else { return }
		
		let ms = Double(hueArray.count) * (1000 / Double(fps))
		
		let bandpassFiltered = butterWorthBandPassFilter(with: hueArray)
		let smoothedBandpass = medianSmoothing(with: bandpassFiltered)
		let peekCount = peakCount(from: smoothedBandpass)
		
		let second = Double(smoothedBandpass.count) / Double(fps)
		let percent = second / 60.0
		let heartbeat = Double(peekCount) / percent
		
		if hueArray.count >= (5 * fps) { // wait 5 sec to calc right value
			DispatchQueue.main.async {
				self.delegate?.heartBeatUpdate(Int(heartbeat), atTime: Int(ms))
			}
		}
		
		if hueArray.count >= duration * fps {
			self.delegate?.heartBeatFinished()
		}
	}
	
	
	// MARK: calculat heartbeast from brightness
	
	func butterWorthBandPassFilter(with array: [CGFloat]) -> [CGFloat] {
		let dGain = 1.232232910e+02; // constant value
		var out = [CGFloat]()
		
		for f in array {
			for i in 1 ..< matrixCount {
				xv[i - 1] = xv[i]
				yv[i - 1] = yv[i]
				
			}
			xv[matrixCount - 1] = f / CGFloat(dGain)
			yv[matrixCount - 1] = (xv[0] + xv[8]) - 4 * (xv[2] + xv[6]) + 6 * xv[4] +
								(-0.1397436053 * yv[0]) + (1.2948188815 * yv[1]) +
								( -5.4070037946 * yv[2]) + ( 13.2683981280 * yv[3]) +
								(-20.9442560520 * yv[4]) + ( 21.7932169160 * yv[5]) +
								(-14.5817197500 * yv[6]) + (  5.7161939252 * yv[7])
			
			out.append(yv[8])
		}
		
		return out
	}
	
	
	func peakCount(from array: [CGFloat]) -> Int {
		guard array.count > 0 else { return 0 }
		
		var count = 0, i = 3
		while i < array.count - 3 {
			if array[i] > 0 &&
				array[i] > array[i - 1] && array[i] > array[i - 2] && array[i] > array[i - 3] &&
				array[i] >= array[i + 1] && array[i] >= array[i + 2] && array[i] >= array[i + 3] {
				count = count + 1
				i = i + 4
			} else {
				i = i + 1
			}
		}
		
		return count
	}
	
	
	func medianSmoothing(with array: [CGFloat]) -> [CGFloat] {
		var out = [CGFloat]()
		
		for i in 0 ..< array.count {
			if i == 0 || i == 1 || i == 2 ||
				i == array.count - 1 || i == array.count - 2 || i == array.count - 3 {
				out.append(array[i])
				
			} else {
				out.append(array[i-2 ... i+2].sorted()[2])
			}
		}
		
		return out
	}
}
