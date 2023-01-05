//
//  RemoteInterfaceController.swift
//  Roku Remote WatchKit Extension
//
//  Created by Josh Birnholz on 10/9/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import WatchKit
import RokuKit_Watch

extension Array {
	public subscript (safe index: Index) -> Element? {
		return indices.contains(index) ? self[index] : nil
	}
	
	public func chunked(by chunkSize: Int) -> [[Element]] {
		return stride(from: 0, to: self.count, by: chunkSize).map {
			Array(self[$0..<Swift.min($0 + chunkSize, self.count)])
		}
	}
}

class RemoteInterfaceController: WKInterfaceController {
	
	var device: RokuDevice?
	
	let volumeThreshold: Double = 0.1
	
	var rotationAmount: Double = 0.0 {
		didSet {
			guard let device = device else { return }
			let times = Int(rotationAmount/volumeThreshold)
			if times > 0 {
				print(Date(), "Volume up \(times)")
				rotationAmount -= Double(times)*volumeThreshold
				
				for _ in (0 ..< times) {
					device.send(keypress: .VolumeUp)
				}
				WKInterfaceDevice.current().play(.click)
				
				
			} else if times < 0 {
				print(Date(), "Volume down \(times)")
				rotationAmount -= Double(times)*volumeThreshold
				
				for _ in (0 ..< times * -1) {
					device.send(keypress: .VolumeDown)
				}
				WKInterfaceDevice.current().play(.click)
			}
		}
	}
	
	@IBOutlet var swipeButton: WKInterfaceButton!
	@IBOutlet var buttonsGroup: WKInterfaceGroup!
	
	override func awake(withContext context: Any?) {
		guard let device = context as? RokuDevice else { dismiss(); return }
		
		self.device = device
		
		updateRemote()
		
	}
	
	override func didAppear() {
		guard let device = device else { return }
		
		if device.isTV {
			crownSequencer.delegate = self
			crownSequencer.focus()
		}
	}
	
	func updateRemote() {
		switch RemoteStyle.savedRemoteStyle {
		case .button:
			buttonsGroup.setHidden(false)
			swipeButton.setHidden(true)
		case.swipe:
			buttonsGroup.setHidden(true)
			swipeButton.setHidden(false)
		}
	}
	
	@IBAction func backButtonPressed() {
		device?.send(keypress: .Back)
	}
	
	@IBAction func micButtonPressed() {
		guard let device = device else { return }
		presentTextInputController(withSuggestions: [], allowedInputMode: .plain) { results in
			if let text = (results?.first as? String) {
				device.send(litString: text)
			}
		}
	}
	
	@IBAction func homeButtonPressed() {
		device?.send(keypress: .Home)
	}
	
	@IBAction func upGestureRecognized(_ sender: Any) {
		device?.send(keypress: .Up)
		WKInterfaceDevice.current().play(.click)
	}
	
	@IBAction func downGestureRecognized(_ sender: Any) {
		device?.send(keypress: .Down)
		WKInterfaceDevice.current().play(.click)
	}
	
	@IBAction func leftGestureRecognized(_ sender: Any) {
		device?.send(keypress: .Left)
		WKInterfaceDevice.current().play(.click)
	}
	
	@IBAction func rightGestureRecognized(_ sender: Any) {
		device?.send(keypress: .Right)
		WKInterfaceDevice.current().play(.click)
	}
	
	@IBAction func tapGestureRecognized(_ sender: Any) {
		device?.send(keypress: .Select)
		WKInterfaceDevice.current().play(.click)
	}
	
	@IBAction func optionsMenuItemPressed() {
		device?.send(keypress: .Info)
	}
	
	@IBAction func powerMenuItemPressed() {
		device?.send(keypress: .Power)
	}
	
	@IBAction func muteButtonPressed() {
		device?.send(keypress: .VolumeMute)
	}
	
}

extension RemoteInterfaceController: WKCrownDelegate {
	
	func crownDidRotate(_ crownSequencer: WKCrownSequencer?, rotationalDelta: Double) {
		rotationAmount += rotationalDelta
	}
	
	func crownDidBecomeIdle(_ crownSequencer: WKCrownSequencer?) {
		rotationAmount = 0
	}
	
}
