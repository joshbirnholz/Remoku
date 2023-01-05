//
//  SplashViewController.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/26/19.
//  Copyright © 2019 Josh Birnholz. All rights reserved.
//

import UIKit

class SplashViewController: UIViewController {

	@IBOutlet weak var shortcutsGroup: UIStackView!
	
	override func viewDidLoad() {
        super.viewDidLoad()
		
		shortcutsGroup.isHidden = !ProcessInfo().isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 13, minorVersion: 0, patchVersion: 0))
		
		let gesture = UITapGestureRecognizer(target: self, action: #selector(shortcutsButtonPressed(_:)))
		shortcutsGroup.addGestureRecognizer(gesture)

        // Do any additional setup after loading the view.
    }
	
	override func viewWillAppear(_ animated: Bool) {
		self.navigationController?.setNavigationBarHidden(true, animated: animated)
		super.viewWillAppear(animated)
	}

	override func viewWillDisappear(_ animated: Bool) {
		self.navigationController?.setNavigationBarHidden(false, animated: animated)
		super.viewWillDisappear(animated)
	}
    
	@objc func shortcutsButtonPressed(_ sender: Any) {
		let url = URL(string: "shortcuts://")!
		if UIApplication.shared.canOpenURL(url) {
			UIApplication.shared.open(url)
		} else {
			let appStoreURL = URL(string: "https://apps.apple.com/us/app/shortcuts/id915249334")!
			UIApplication.shared.open(appStoreURL)
		}
		
//		performSegue(withIdentifier: "ShortcutsDeviceFinder", sender: sender)
	}
	

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
