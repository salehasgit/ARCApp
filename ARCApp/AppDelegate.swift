//
//  AppDelegate.swift
//  ARCApp
//

import Cocoa
import AppleRawConverter

import Fabric
import Crashlytics

var serial = ""

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func mkdir(_ directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            Log.error("Unable to create the directory: \(error)")
        }
    }
    
    func getLaunchArguments() -> [URL] {
        
        //experimenting with CommandLine.argc
//        let dd = CommandLine.argc //two extras! "-NSDocumentRevisionsDebugMode" and "YES"
//        let arguments = CommandLine.arguments
//        for argument in arguments{print(argument)}
        
        var inputArgsURLs: [URL] = []
        var file = UserDefaults.standard.url(forKey: "param")
        if(file == nil){
            Log.error("No src is passed. try \"ARCApp -src source.cr2 -dst destination.tiff -param appleParamsDir\"")
            NSApplication.shared.terminate(self)
        } else {
            inputArgsURLs.append(file!)
        }
        
        file = UserDefaults.standard.url(forKey: "src")
        if(file == nil){
            Log.error("No src is passed. try \"ARCApp -src source.cr2 -dst destination.tiff -param appleParamsDir\"")
            NSApplication.shared.terminate(self)
        } else {
            inputArgsURLs.append(file!)
            if !(file?.lastPathComponent.contains("user"))! {
                file?.deleteLastPathComponent()
                file?.appendPathComponent("shot_off.cr2")
                inputArgsURLs.append(file!)
            }
        }
        
        file = UserDefaults.standard.url(forKey: "dst")
        if(file == nil){
            Log.error("No src is passed. try \"ARCApp -src source.cr2 -dst destination.tiff -param appleParamsDir\"")
            NSApplication.shared.terminate(self)
        } else {
            inputArgsURLs.append(file!)
            if !(file?.lastPathComponent.contains("user"))! {
                file?.deleteLastPathComponent()
                file?.appendPathComponent("fromRawCon_off8bit.tif")
                inputArgsURLs.append(file!)
            }
        }
        
        return inputArgsURLs
    }

    
    func getAppleRawParameters(from parametersDirectory: String) throws -> AppleRawParameters {
        
        //let parametersDirectory: String = NSHomeDirectory() + "/Dropbox (VR Holding BV)/Dataset/Live/parameters"
        let parametersURL = URL(fileURLWithPath: parametersDirectory + "/raw.json")
        
        let parameters: String
        do {
            parameters = try String(contentsOf: parametersURL)
        } catch let error {
            throw LogError.failedToGetAppleRawParameters("Unable to load \"raw.json\" from \(parametersURL) : \(error).")
        }
        
        guard let appleRawParameters = AppleRawParameters.deserialize(from: parameters) else {
            throw LogError.failedToGetAppleRawParameters("AppleRawParameters.deserialize: failed to deserialize the Json content")
        }
        
        return appleRawParameters
    }
    
    func DoAppleRawConverter(to inputArgsURL: [URL], with appleRawParameters: AppleRawParameters) {
        let dngConvert = UserDefaults.standard.bool(forKey: "dng") // False by default.
        let appleRawConverter = AppleRawConverter(dngConvert: dngConvert)
        
        let src = inputArgsURL[0]
        let dst = inputArgsURL[1]
        
        Log.verbose("Processing raw source \(src).")
        do {
            try autoreleasepool {
                let rawImage = appleRawConverter.processRaw(from: src, with: appleRawParameters)
                if( rawImage != nil ){
                    do {
                        try rawImage?.writeTIFFRepresentation(to: dst, format: CIFormat.RGBA8)
                        Log.verbose("TIFF was written to \(dst)")
                        
                        let applyCAcorr = UserDefaults.standard.bool(forKey: "doCAcorr") // False by default.
                        let start = DispatchTime.now() // <<<<<<<<<< Start time
                        if (applyCAcorr){
                            let focalLength = UserDefaults.standard.integer(forKey: "focalLength")
                            let LensModel = UserDefaults.standard.string(forKey: "lensModel")
                            Log.verbose("CA is going to be corrected using these params: focalLength:\(focalLength), lensModel:\(LensModel!)")
                            try rawImage?.removeCA(from: dst, takenAtFocal: UInt(focalLength), usingLensModel: LensModel!, usingParameters: appleRawParameters)
                            Log.verbose("CA was corrected and written to \(dst.deletingPathExtension().appendingPathExtension("_CAcorrected.tif"))")
                        }
                        let end = DispatchTime.now()   // <<<<<<<<<<   end time
                        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
                        let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests
                        LogEvent(name: "CA removal", attributes: ["duration": timeInterval], "Removing CA took \(timeInterval) seconds")

                        
                    } catch let error {
                        Log.error("Unable to write TIFF: \(error)")
                    }
                } else
                {
                    Log.error("Faild processing raw source \(src).")
                }
            }
        } catch let error {
            Log.error("Unable to convert : \(error).")
        }
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // Turn on crash on un-catched exceptions.
        // https://docs.fabric.io/apple/crashlytics/os-x.html
        UserDefaults.standard.register(defaults: ["NSApplicationCrashOnExceptions" : true])
        
        // Register Fabric
        Crashlytics.sharedInstance().delegate = self
        Fabric.with([Crashlytics.self, Answers.self])
        
        // Retrieve the localhost name
//        let serial = 1.0
        let (uuid, _serial) = getSystemUUID()
        serial = _serial
        Crashlytics.sharedInstance().setUserIdentifier(serial) //AppInfo.shared.host.runSystemSerial
        Crashlytics.sharedInstance().setUserEmail("\(uuid)")
        Crashlytics.sharedInstance().setUserName(Host.current().localizedName ?? "")
        Crashlytics.sharedInstance().setObjectValue("1.0", forKey: "core_version")
        
        // custom event
        LogEvent(name: "Application started", "Let's do some conversions!")
        
        
        // Insert code here to initialize your application
        // get launch args
        let srcdstURLs: [URL] = getLaunchArguments()
        
        // exit if the source or destination folder does not exist (we need this for C++ core to work correctly)
        var srcON: URL
        var dstLogBase: URL
        if !(srcdstURLs[1].lastPathComponent.contains("user")) {
            srcON = srcdstURLs[1]
            dstLogBase = srcdstURLs[3].deletingLastPathComponent()
        }
        else {
            srcON = srcdstURLs[1]
            dstLogBase = srcdstURLs[2].deletingLastPathComponent()
        }
        
        if !FileManager.default.fileExists(atPath: srcON.path) ||  !FileManager.default.fileExists(atPath: dstLogBase.path) {
            NSApplication.shared.terminate(self)
        }
        
         // set file-based Logger
         let fileLogger = FileLogger(basePath: dstLogBase,
                                    baseFileName: "rawtotif_ARCApp.log",
                                    verbosity: .verbose)   // show info or more level of logging.
        
        Logger.externalLogger = RAWConverterLogger(logLevel: .verbose)
        
        Log.shared.addLogTarget(logger: fileLogger)
        Log.verbose("application did Finish Launching, launch args were set and of course this logger was set too!...")

        let start = DispatchTime.now() // <<<<<<<<<< Start time
        // get parameters
        Log.verbose("getting Apple raw parameters...")
        var appleRawParameters = AppleRawParameters() //default values
        do {
            appleRawParameters = try getAppleRawParameters(from: srcdstURLs[0].path)
        } catch let error {
            Log.error("unable to get Apple raw parameters : \(error)")
            NSApplication.shared.terminate(self) // default will do no good! so quit the app
        }

        if !(srcdstURLs[1].lastPathComponent.contains("user")) {
            // converting ON raw file
            DoAppleRawConverter(to: Array([srcdstURLs[1], srcdstURLs[3]]), with: appleRawParameters)
            // converting OFF raw file
            DoAppleRawConverter(to: Array([srcdstURLs[2], srcdstURLs[4]]), with: appleRawParameters)
        }
        else {
            // converting USER raw file
            DoAppleRawConverter(to: Array([srcdstURLs[1], srcdstURLs[2]]), with: appleRawParameters)
        }
        
        let end = DispatchTime.now()   // <<<<<<<<<<   end time
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds // <<<<< Difference in nano seconds (UInt64)
        let timeInterval = Double(nanoTime) / 1_000_000_000 // Technically could overflow for long running tests
        LogEvent(name: "Conversion", attributes: ["duration": timeInterval], "The conversion took \(timeInterval) seconds")
        
        // quit the app
        NSApplication.shared.terminate(self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

extension AppDelegate: CrashlyticsDelegate {
    func crashlyticsDidDetectReport(forLastExecution report: CLSReport, completionHandler: @escaping (Bool) -> Void) {
        // You should take some set of actions here based on knowing that a crash happened, but then make sure to call the completion handler
        // If you don't call the completion handler, the SDK will not submit the crash report.
        completionHandler(true)
    }
}

func getSystemUUID() -> (uuid: String, serial: String) {
    let dev = IOServiceMatching("IOPlatformExpertDevice")
    let platformExpert: io_service_t = IOServiceGetMatchingService(kIOMasterPortDefault, dev)
    let UUIDAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as? CFString, kCFAllocatorDefault, 0)
    let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformSerialNumberKey as? CFString, kCFAllocatorDefault, 0)
    IOObjectRelease(platformExpert)
    let uuid = UUIDAsCFString?.takeUnretainedValue() as? String ?? ""
    let ser = serialNumberAsCFString?.takeUnretainedValue() as? String ?? ""
    return (uuid, ser)
}

func LogEvent(name: String, attributes: [String: Any] = [:], _ line: String = "") {
    var augmentedAttributes: [String: Any]? = attributes
    augmentedAttributes?["Machine ID"] = serial
    
    Answers.logCustomEvent(withName: name,
                           customAttributes: augmentedAttributes)
    
    Log.info("Event: \(name): \(line)")
}
