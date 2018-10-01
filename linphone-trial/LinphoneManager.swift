import Foundation


let YOUR_SIP_DOMAIN = "sip3.biyah.pk"

var canRecieveCall: Bool = true


extension Notification.Name {
    
    static let ABIncomingCallNotification = Notification.Name("ABIncomingCallNotification")
    static let ABOutgoingCallInitNotification = Notification.Name("ABOutgoingCallInitNotification")
    static let ABOutgoingCallProgressNotification = Notification.Name("ABOutgoingCallProgressNotification")
    static let ABCallConnectNotification = Notification.Name("ABCallConnectNotification")
    static let ABCallEndNotification = Notification.Name("ABCallEndNotification")
    static let ABCallTimerNotification = Notification.Name("ABCallTimerNotification")

    
}

struct theLinphone {
    static var lc: OpaquePointer?
    static var lct: LinphoneCoreVTable?
    static var manager: LinphoneManager?
}

let registrationStateChanged: LinphoneCoreRegistrationStateChangedCb  = {
    (lc: Optional<OpaquePointer>, proxyConfig: Optional<OpaquePointer>, state: _LinphoneRegistrationState, message: Optional<UnsafePointer<Int8>>) in
    
    switch state{
    case LinphoneRegistrationNone: /**<Initial state for registrations */
        NSLog("LinphoneRegistrationNone")
        
    case LinphoneRegistrationProgress:
        NSLog("LinphoneRegistrationProgress")
        
    case LinphoneRegistrationOk:
        NSLog("LinphoneRegistrationOk")
        
    case LinphoneRegistrationCleared:
        NSLog("LinphoneRegistrationCleared")
        
    case LinphoneRegistrationFailed:
        NSLog("LinphoneRegistrationFailed")
        
    default:
        NSLog("Unkown registration state")
    }
    } as LinphoneCoreRegistrationStateChangedCb

let callStateChanged: LinphoneCoreCallStateChangedCb = {
    (lc: Optional<OpaquePointer>, call: Optional<OpaquePointer>, callSate: LinphoneCallState,  message: Optional<UnsafePointer<Int8>>) in
    
    switch callSate{
    case LinphoneCallIncomingReceived: /**<This is a new incoming call */
        NSLog("callStateChanged: LinphoneCallIncomingReceived")
        
        
        if canRecieveCall{
            NotificationCenter.default.post(name: .ABIncomingCallNotification, object: nil)
        }
        
    case LinphoneCallStreamsRunning: /**<The media streams are established and running*/
        
        NotificationCenter.default.post(name: .ABCallConnectNotification, object: nil)
        
    case LinphoneCallEnd:
        NSLog("callStateChanged")
        
    case LinphoneCallError: /**<The call encountered an error*/
        NSLog("callStateChanged: LinphoneCallError")
        
    default:
        NSLog("Default call state")
    }
}


class LinphoneManager {
    
    static var iterateTimer: Timer?
    var callTimer:Timer?
    
    init(userName:String, password:String) {
        
        theLinphone.lct = LinphoneCoreVTable()
        
        // Enable debug log to stdout
        linphone_core_set_log_file(nil)
        linphone_core_set_log_level(ORTP_DEBUG)
        
        // Load config
        let configFilename = documentFile("linphonerc222")
        let factoryConfigFilename = bundleFile("linphonerc-factory")
        
        let configFilenamePtr: UnsafePointer<Int8> = configFilename.cString(using: String.Encoding.utf8.rawValue)!
        let factoryConfigFilenamePtr: UnsafePointer<Int8> = factoryConfigFilename.cString(using: String.Encoding.utf8.rawValue)!
        let lpConfig = lp_config_new_with_factory(configFilenamePtr, factoryConfigFilenamePtr)
        
        // Set Callback
        theLinphone.lct?.registration_state_changed = registrationStateChanged
        theLinphone.lct?.call_state_changed = callStateChanged
        
        theLinphone.lc = linphone_core_new_with_config(&theLinphone.lct!, lpConfig, nil)
        
        // Set ring asset
        let ringbackPath = URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent("/ringback.wav").absoluteString
        linphone_core_set_ringback(theLinphone.lc, ringbackPath)
        
        let localRing = URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent("/toy-mono.wav").absoluteString
        linphone_core_set_ring(theLinphone.lc, localRing)
        
        if let proxyConfig = setIdentify(account: userName, password: password, domain: YOUR_SIP_DOMAIN){
            theLinphone.manager = self
            register(proxyConfig)
            setTimer()
            
            NotificationCenter.default.addObserver(forName: .ABCallConnectNotification, object: nil, queue: OperationQueue.main) { (not) in
                
                self.startCallTimer()
                
            }
        }
    }
    
    fileprivate func bundleFile(_ file: NSString) -> NSString{
        return Bundle.main.path(forResource: file.deletingPathExtension, ofType: file.pathExtension)! as NSString
    }
    
    fileprivate func documentFile(_ file: NSString) -> NSString {
        let paths = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        
        let documentsPath: NSString = paths[0] as NSString
        return documentsPath.appendingPathComponent(file as String) as NSString
    }
    
    func dialCall(userName:String, callback:((Bool)->())){
        
        if theLinphone.lc != nil{
            linphone_core_invite(theLinphone.lc, userName)
        }
        else{
            print("Linphone Not Initialized")
            callback(false)
        }
        
    }
    
    func acceptCall() -> Bool{
        
        if let lc = theLinphone.lc{
            if let call = linphone_core_get_current_call(lc){
                linphone_core_accept_call(lc, call)
                linphone_call_ref(call)
                return true
            }
        }
        return false
    }
    
    //if the user is busy, this will reject call
    func rejectCall(call:Optional<OpaquePointer>?){
        
        if let lc = theLinphone.lc{
            
            //if rejecting call because of another call
            if let call = call{
                linphone_core_decline_call(lc, call, LinphoneReasonBusy)
            }
            else if let call = linphone_core_get_current_call(lc){
//                linphone_core_decline_call(lc, call, LinphoneReasonNone)
                linphone_core_terminate_call(lc, call)
            }
            self.stopCallTimer()
        }
    }
    //if the call has end by this user, this will end the call
    func hangUp(){
        if let lc = theLinphone.lc{
            if let call = linphone_core_get_current_call(lc){
                linphone_core_decline_call(lc, call, LinphoneReasonNone)
                linphone_call_unref(call)
            }
        }
    }
    
    
    func setIdentify(account:String, password:String, domain:String) -> OpaquePointer? {
        
        // Reference: http://www.linphone.org/docs/liblinphone/group__registration__tutorials.html
        
        
//        let account = "9109799432317"
//        let password = "password"
//        let domain = "sip3.biyah.pk:7000"
        
        let identity = "sip:" + account + "@" + domain;
        
        /*create proxy config*/
        let proxy_cfg = linphone_proxy_config_new();
        
        /*parse identity*/
        let from = linphone_address_new(identity);
        
        if (from == nil){
            NSLog("\(identity) not a valid sip uri, must be like sip:toto@sip.linphone.org");
            return nil
        }
        
        let info=linphone_auth_info_new(linphone_address_get_username(from), nil, password, nil, nil, nil); /*create authentication structure from identity*/
        linphone_core_add_auth_info(theLinphone.lc, info); /*add authentication info to LinphoneCore*/
        
        // configure proxy entries
        linphone_proxy_config_set_identity(proxy_cfg, identity); /*set identity with user name and domain*/
        let server_addr = String(cString: linphone_address_get_domain(from)); /*extract domain address from identity*/
        
        linphone_address_destroy(from); /*release resource*/
        
        linphone_proxy_config_set_server_addr(proxy_cfg, server_addr); /* we assume domain = proxy server address*/
        linphone_proxy_config_enable_register(proxy_cfg, 0); /* activate registration for this proxy config*/
        linphone_core_add_proxy_config(theLinphone.lc, proxy_cfg); /*add proxy config to linphone core*/
        linphone_core_set_default_proxy_config(theLinphone.lc, proxy_cfg); /*set to default proxy*/
        
        return proxy_cfg!
    }
    
    func register(_ proxy_cfg: OpaquePointer){
        linphone_proxy_config_enable_register(proxy_cfg, 1); /* activate registration for this proxy config*/
    }
    
    func shutdown(callback:@escaping (()->())){
        
        NSLog("Shutdown..")
        
        LinphoneManager.iterateTimer?.invalidate()
        
        DispatchQueue(label: "ab").async {
            let proxy_cfg = linphone_core_get_default_proxy_config(theLinphone.lc); /* get default proxy config*/
            linphone_proxy_config_edit(proxy_cfg); /*start editing proxy configuration*/
            linphone_proxy_config_enable_register(proxy_cfg, 0); /*de-activate registration for this proxy config*/
            linphone_proxy_config_done(proxy_cfg); /*initiate REGISTER with expire = 0*/
//            while(linphone_proxy_config_get_state(proxy_cfg) !=  LinphoneRegistrationCleared){
//                linphone_core_iterate(theLinphone.lc); /*to make sure we receive call backs before shutting down*/
//                //ms_usleep(50000);
//            }
            
            
            DispatchQueue.main.async {
                linphone_core_destroy(theLinphone.lc);
                callback()
            }
        }
    }
    
    @objc func iterate(){
        if let lc = theLinphone.lc{
            linphone_core_iterate(lc); /* first iterate initiates registration */
        }
    }
    
    fileprivate func setTimer(){
        LinphoneManager.iterateTimer = Timer.scheduledTimer(
            timeInterval: 0.02, target: self, selector: #selector(iterate), userInfo: nil, repeats: true)
    }
    
    fileprivate func startCallTimer(){
        self.callTimer = Timer.scheduledTimer(
            timeInterval: 0.1, target: self, selector: #selector(callTimerTick), userInfo: nil, repeats: true)
    }
    fileprivate func stopCallTimer(){
        self.callTimer?.invalidate()
        self.callTimer = nil
    }
    
    @objc func callTimerTick(){
        if let lc = theLinphone.lc{
            let duration = linphone_core_get_current_call_duration(lc)
            NotificationCenter.default.post(name: .ABCallTimerNotification, object: nil, userInfo: ["time":"\(duration)"])
        }
    }
   
}
//
// This is the start point to know how linphone library works.
//
//    func demo() {
//         //       makeCall()
//        //        autoPickImcomingCall()
//        idle()
//    }

//    func makeCall(){
//        let calleeAccount = "9109314291645"
//
//        guard let _ = setIdentify() else {
//            print("no identity")
//            return;
//        }
//        linphone_core_invite(theLinphone.lc, calleeAccount)
//        setTimer()
//        //        shutdown()
//    }



//    func receiveCall(){
//        guard let proxyConfig = setIdentify() else {
//            print("no identity")
//            return;
//        }
//        register(proxyConfig)
//        setTimer()
//        //        shutdown()
//    }


