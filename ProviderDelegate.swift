/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import CallKit
import AVFoundation
import UIKit

class ProviderDelegate: NSObject{
    
    var callController:CXCallController!
    
    fileprivate let provider: CXProvider
    
    
    override init() {
        
        provider = CXProvider(configuration: type(of: self).providerConfiguration)
        
        super.init()
        
        self.callController = CXCallController(queue: DispatchQueue.main)
        
        provider.setDelegate(self, queue: nil)
    }
    
    static var providerConfiguration: CXProviderConfiguration {
        let providerConfiguration = CXProviderConfiguration(localizedName: "Biyah")
        
        providerConfiguration.ringtoneSound = "/toy-mono.wav"
        providerConfiguration.iconTemplateImageData = UIImagePNGRepresentation(#imageLiteral(resourceName: "icon"))
        providerConfiguration.supportsVideo = false
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.phoneNumber, .generic]
        
        return providerConfiguration
    }
    
    func reportIncomingCall(uuid: UUID, handle: String, hasVideo: Bool = false, completion: ((NSError?) -> Void)?) {
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        update.hasVideo = hasVideo
        
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if error == nil {
                
            }
            
            completion?(error as? NSError)
        }
    }
}

// MARK: - CXProviderDelegate

extension ProviderDelegate: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        stopAudio()
        
//        for call in callManager.calls {
//            call.end()
//        }
//
//        callManager.removeAllCalls()
    }
    //MARK: CXAnswerCallAction
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        
        if let manager = theLinphone.manager{
            if manager.answerCall(){
                manager.uuid = action.uuid
                if let caleeName = theLinphone.manager?.getCurrentCallDisplayName(){
                    appDel.showCallViewController(callerName: caleeName, displayImage: #imageLiteral(resourceName: "user"))
                    action.fulfill()
                }
            }
        }
        
        action.fail()
        
        
    }
    //MARK: CXEndCallAction
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {

        theLinphone.manager?.hangUp()
        
        action.fulfill()

    }
    //MARK: CXSetHeldCallAction
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
//        guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
//            action.fail()
//            return
//        }
//
//        call.state = action.isOnHold ? .held : .active
//
//        if call.state == .held {
//            stopAudio()
//        } else {
//            startAudio()
//        }
        
        action.fulfill()
    }
    //MARK: CXStartCallAction
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        
        configureAudioSession()
        
        startAudio()
        
        theLinphone.manager!.dialCall(userName: action.handle.value, uuid: action.uuid, callback: { fin in
            
            if fin{
                action.fulfill()
            }
            else{
                stopAudio()
                action.fail()
            }
        })
        

    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        startAudio()
    }
    
    func requestTransaction(_ transaction: CXTransaction) {
        callController.request(transaction) { error in
            if let error = error {
                print("Error requesting transaction: \(error)")
            } else {
                print("Requested transaction successfully")
            }
        }
    }
}
