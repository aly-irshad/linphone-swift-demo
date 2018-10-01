//
//  ViewController.swift
//  linphone-trial
//
//  Created by Cody Liu on 6/7/16.
//  Copyright © 2016 WiAdvance. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var txtNumber: UITextField!
    @IBOutlet weak var btnPlaceCall: UIButton!
    @IBOutlet weak var lblStatus: UILabel!
    @IBOutlet weak var btnPickCall: UIButton!
    @IBOutlet weak var btnEndCall: UIButton!
    
    @IBOutlet weak var btnStartLinphone: UIButton!
    @IBOutlet weak var btnShutDown: UIButton!
    
    var linphoneManager: LinphoneManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
      
        self.lblStatus.text = "Linphone Shut Down"
        
        self.btnPlaceCall.isEnabled = false
        self.btnPickCall.isEnabled = false
        self.btnEndCall.isEnabled = false
        
        self.btnShutDown.isEnabled = false
        
        //add listeners for linphone notifications
        NotificationCenter.default.addObserver(forName: .ABIncomingCallNotification, object: nil, queue: OperationQueue.main) { (not) in
            
            self.btnPlaceCall.isEnabled = false
            
            self.lblStatus.text = "Incoming Call.."
            
        }
        
        NotificationCenter.default.addObserver(forName: .ABOutgoingCallInitNotification, object: nil, queue: OperationQueue.main) { (not) in
            
            self.btnPickCall.isEnabled = false
            self.btnPlaceCall.isEnabled = false
            
            self.lblStatus.text = "Dialing"
            
        }
        NotificationCenter.default.addObserver(forName: .ABOutgoingCallProgressNotification, object: nil, queue: OperationQueue.main) { (not) in
            
            self.lblStatus.text = "Dialing..."
            
        }
        NotificationCenter.default.addObserver(forName: .ABCallConnectNotification, object: nil, queue: OperationQueue.main) { (not) in
            
            self.lblStatus.text = "Call Connected"
            
            
        }
        NotificationCenter.default.addObserver(forName: .ABCallEndNotification, object: nil, queue: OperationQueue.main) { (not) in
            
            self.btnPickCall.isEnabled = false
            self.btnPlaceCall.isEnabled = false
            
            self.lblStatus.text = "Idle"
            
        }
        
        NotificationCenter.default.addObserver(forName: .ABCallTimerNotification, object: nil, queue: OperationQueue.main) { (not) in
            
            if let time = not.userInfo?["time"] as? String{
                self.lblStatus.text = time
            }
            
        }
                
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func startLinphone(){
        self.linphoneManager = LinphoneManager(userName: "9109799432317", password: "password")
    }
    @IBAction func onPlaceCall(_ sender: Any) {
        
        if let manager = theLinphone.manager{
            if let text = self.txtNumber.text, text.count > 0{
                manager.dialCall(userName: text) { (res) in
                    if !res{
                        self.alertController(msg: "Failed to dial")
                    }
                    else{
                        self.btnPickCall.isEnabled = false
                        self.btnPlaceCall.isEnabled = false
                    }
                }
            }
            else{
                self.alertController(msg: "Enter Phone Number")
            }
            
        }
        else{
            self.alertController(msg: "Manager not found !!")
        }
    }
    
    @IBAction func onPickCall(_ sender: Any) {
        if let manager = theLinphone.manager{
            if !manager.acceptCall(){
                self.alertController(msg: "Failed to pic call")
            }
            else{
                self.btnPickCall.isEnabled = false
                self.btnPlaceCall.isEnabled = false
            }
        }
        else{
            self.alertController(msg: "Manager not found !!")
        }
    }
    
    @IBAction func onEndCall(_ sender: Any) {
        if let manager = theLinphone.manager{
            manager.rejectCall(call: nil)
            self.btnPickCall.isEnabled = true
            self.btnPlaceCall.isEnabled = true
            self.lblStatus.text = "Linphone Active"
        }
        else{
            self.alertController(msg: "Manager not found !!")
        }
    }
    @IBAction func onStartLinphone(_ sender: Any) {
        
        _ = LinphoneManager(userName: "9109799432317", password: "password")
        self.lblStatus.text = "Linphone Started"
        
        self.btnStartLinphone.isEnabled = false
        
        self.btnPlaceCall.isEnabled = true
        self.btnPickCall.isEnabled = true
        self.btnEndCall.isEnabled = true
        
        
        self.btnShutDown.isEnabled = true
    }
    @IBAction func onShutDown(_ sender: Any) {
        
        self.lblStatus.text = "Linphone Shutting Down"
        theLinphone.manager?.shutdown(callback: {
            
            self.lblStatus.text = "Linphone Shut Down"
            
            self.btnShutDown.isEnabled = false
            
            self.btnStartLinphone.isEnabled = true
            self.btnPlaceCall.isEnabled = false
            self.btnPickCall.isEnabled = false
            self.btnEndCall.isEnabled = false
            
        })
        
    }
    
    func alertController(msg:String){
        let alert = UIAlertController(title: "Error", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (alert) in
            
        }))
        self.present(alert, animated: true, completion: nil)
    }
    

}

