import AppKit
import Carbon

class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()
    
    private var hotKeys: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    
    init() {
        setupHandler()
    }
    
    func register(keyCode: UInt32, modifiers: UInt32, identifier: UInt32, handler: @escaping () -> Void) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x43524b44), id: identifier) // 'CRKD'
        
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status == noErr, let ref = hotKeyRef {
            hotKeys[identifier] = ref
            handlers[identifier] = handler
            print("GlobalHotKeyManager: Registered hotkey \(identifier)")
        } else {
            print("GlobalHotKeyManager: Failed to register hotkey \(identifier), status: \(status)")
        }
    }
    
    private func setupHandler() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if status == noErr {
                let identifier = hotKeyID.id
                DispatchQueue.main.async {
                    GlobalHotKeyManager.shared.handlers[identifier]?()
                }
            }
            
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventSpec, nil, nil)
    }
}
