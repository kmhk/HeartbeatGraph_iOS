//
//  HeartbeatGraphView.swift
//  Heartbeat
//
//  Created by Com on 25/01/2017.
//  Copyright © 2017 Com. All rights reserved.
//

import UIKit

var xUnit: CGFloat = 5

struct DrawPoint {
	var bpm: Int
	var time: Int
}

class HeartbeatGraphView: UIView {
	var bpm: Int = 0
	var time: Int = 0
	var points = [DrawPoint]()
	
	override func draw(_ rect: CGRect) {
		let rect = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
		
		UIColor.white.setFill()
		let screen = UIBezierPath(rect: rect)
		screen.fill()
		
		// draw x axis
		let xAxis = UIBezierPath()
		xAxis.move(to: CGPoint(x: 20, y: rect.size.height-40))
		xAxis.addLine(to: CGPoint(x: rect.size.width, y: rect.size.height-40))
		xAxis.close()
		xAxis.stroke()
		
		var o: CGFloat = 40
		while o <= rect.size.width {
			var len: CGFloat = 5
			if (Int(o - 40) % (Int(xUnit) * 30)) == 0 {
				len = 15
				if o > 40 {
					let text: NSString = "\(Int(o - 40) / (Int(xUnit) * 30)) s" as NSString
					text.draw(at: CGPoint(x: o-10, y: rect.size.height-38+len),
					          withAttributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 10),
					                           NSForegroundColorAttributeName: UIColor.blue])
				}
			} else if (Int(o - 40) % (Int(xUnit) * 15)) == 0 {
				len = 10
			}
		
			UIColor.black.setStroke()
			let sc = UIBezierPath()
			sc.move(to: CGPoint(x: o, y: rect.size.height-40)); sc.addLine(to: CGPoint(x: o, y: rect.size.height-40+len)); sc.close()
			sc.stroke()
			
			o = o + xUnit
		}
		
		// draw y axix
		let yAxis = UIBezierPath()
		yAxis.move(to: CGPoint(x: 40, y: rect.size.height - 40)); yAxis.addLine(to: CGPoint(x: 40, y: 0)); yAxis.close()
		yAxis.stroke()
		
		var yUnit = (rect.size.height - 40) / 20
		o = rect.size.height - 40 - yUnit
		var strUnit = 40
		while o > 0 {
			let sc = UIBezierPath()
			UIColor.black.setStroke()
			sc.move(to: CGPoint(x: 30, y: o)); sc.addLine(to: CGPoint(x: 40, y: o)); sc.close()
			sc.stroke()
			
			let text: NSString = "\(strUnit)" as NSString
			text.draw(at: CGPoint(x: 10, y: o-5),
			          withAttributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 8),
			                           NSForegroundColorAttributeName: UIColor.green])
			
			o = o - yUnit
			strUnit = strUnit + 10
		}
		
		// draw bpm per ms
		yUnit = yUnit / 10
		UIColor.red.setStroke()
		let bpm = UIBezierPath()
		for i in 0 ..< points.count {
			let pt = points[i]
			let x: CGFloat = 40 + xUnit * CGFloat(i)
			let y: CGFloat = (rect.size.height - 40) - (yUnit * CGFloat(pt.bpm-30))
			
			if i == 0 {
				bpm.move(to: CGPoint(x: x, y: y))
			} else {
				bpm.addLine(to: CGPoint(x: x, y: y))
			}
		}
		bpm.stroke()
	}
	
	
	func reset() {
		points.removeAll()
		setNeedsDisplay()
	}
	
	
	func drawGraph(with bpm: Int, time: Int) {
		let one = DrawPoint(bpm: bpm, time: time)
		points.append(one)
		
		if (CGFloat(points.count) * xUnit + 40) > frame.size.width {
			frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: (CGFloat(points.count) * xUnit + 40), height: frame.size.height)
		}
		
		setNeedsDisplay()
	}
}
