//
//  SettingsTableViewController.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/14/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import UIKit
import RokuKit

var navigateWithButtonsPreference = Stored<Bool>(key: "navigateWithButtons", store: UserDefaults.standard, defaultValue: false)

class SettingsTableViewController: UITableViewController {

	@IBOutlet weak var navigateWithButtonsSwitch: UISwitch!
	
	override func viewDidLoad() {
        super.viewDidLoad()
		
		navigateWithButtonsSwitch.isOn = navigateWithButtonsPreference.wrappedValue
    }

	@IBAction func navigateWithButtonsSwitchToggled(_ sender: Any) {
		
		navigateWithButtonsPreference.wrappedValue = navigateWithButtonsSwitch.isOn
		
	}
	
}
