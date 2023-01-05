//
//  KeyPress.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/8/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import Foundation

public enum KeyPress: RawRepresentable {
	public typealias RawValue = String
	
	case Home
	case Rev
	case Fwd
	case Play
	case Select
	case Left
	case Right
	case Down
	case Up
	case Back
	case InstantReplay
	case Info
	case Backspace
	case Search
	case Enter
	
	/// Only available on certain devices
	case FindRemote
	
	/// Only available on Roku TVs
	case VolumeDown
	/// Only available on Roku TVs
	case VolumeMute
	/// Only available on Roku TVs
	case VolumeUp
	/// Only available on Roku TVs
	case PowerOff
	/// Only available on Roku TVs
	case PowerOn
	/// Only available on Roku TVs
	case Power
	
	/// Only available on Roku TVs
	case ChannelUp
	/// Only available on Roku TVs
	case ChannelDown
	
	/// Only available on Roku TVs
	case InputTuner
	/// Only available on Roku TVs
	case InputHDMI1
	/// Only available on Roku TVs
	case InputHDMI2
	/// Only available on Roku TVs
	case InputHDMI3
	/// Only available on Roku TVs
	case InputHDMI4
	/// Only available on Roku TVs
	case InputAV1
	
	case Lit(Character)
	
	public var isAvailableForTV: Bool {
		switch self {
		case .VolumeUp, .VolumeDown, .VolumeMute, .PowerOff, .PowerOn, .Power, .ChannelUp, .ChannelDown, .InputTuner, .InputHDMI1, .InputHDMI2, .InputHDMI3, .InputHDMI4, .InputAV1:
			return true
		default:
			return false
		}
	}
	
	public var rawValue: String {
		switch self {
		case .Lit(let c):
			return "Lit_" + String(c)
		default:
			return String(describing: self)
		}
	}
	
	public init?(rawValue: KeyPress.RawValue) {
		switch rawValue {
		case "Home": self = .Home
		case "Rev": self = .Rev
		case "Fwd": self = .Fwd
		case "Play": self = .Play
		case "Select": self = .Select
		case "Left": self = .Left
		case "Right": self = .Right
		case "Down": self = .Down
		case "Up": self = .Up
		case "Back": self = .Back
		case "InstantReplay": self = .InstantReplay
		case "Info": self = .Info
		case "Backspace": self = .Backspace
		case "Search": self = .Search
		case "Enter": self = .Enter
		case "FindRemote": self = .FindRemote
		case "VolumeDown": self = .VolumeDown
		case "VolumeMute": self = .VolumeMute
		case "VolumeUp": self = .VolumeUp
		case "PowerOff": self = .PowerOff
		case "PowerOn": self = .PowerOn
		case "Power": self = .Power
		case "ChannelUp": self = .ChannelUp
		case "ChannelDown": self = .ChannelDown
		case "InputTuner": self = .InputTuner
		case "InputHDMI1": self = .InputHDMI1
		case "InputHDMI2": self = .InputHDMI2
		case "InputHDMI3": self = .InputHDMI3
		case "InputHDMI4": self = .InputHDMI4
		case "InputAV1": self = .InputAV1
		case _ where rawValue.hasPrefix("Lit_"):
			if let str = rawValue[rawValue.index(rawValue.startIndex, offsetBy: 4)...].removingPercentEncoding, str.count == 1 {
				self = .Lit(str.first!)
			} else {
				fallthrough
			}
		default:
			return nil
		}
	}
}
