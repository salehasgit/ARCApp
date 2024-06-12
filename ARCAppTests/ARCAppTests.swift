//
//  ARCAppTests.swift
//  ARCAppTests
//

import XCTest
import Nimble
@testable import AppleRawConverter
@testable import AutoAlpha

class RawConvertionAndWritingTests: XCTestCase {
    
    static let dropboxDirectory = NSHomeDirectory() + "/Dropbox (VR Holding BV)"
    static let appleRAWDatasetDirectory = dropboxDirectory + "/Apple RAW converter"
    var rawImageDirectory: String = appleRAWDatasetDirectory + "/ARC_test_pack/Src/SV-096_OSX10.10.5_MKIII"
    var dstImageDirectory: String = appleRAWDatasetDirectory + "/ARC_test_pack/Dst"
    var parametersDirectory: String = appleRAWDatasetDirectory + "/ARC_test_pack/params"
    
    var bundle = Bundle.main
    
    override func setUp() {
        super.setUp()
        bundle = Bundle(for: RawConvertionAndWritingTests.self)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testAppleRawConverter() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    // only CA removal test, uses default Apple raw converter parameters
    func testCARemoval() {
        if #available(OSX 10.12, *) {
            let cr2URL = URL(fileURLWithPath: rawImageDirectory + "/shot_off_20.cr2")
            let tiffURL = URL(fileURLWithPath: dstImageDirectory + "/shot_off_20.tif")
            
            let appleRawConverter = AppleRawConverter()
            let rawImage = appleRawConverter.processRaw(from: cr2URL)
            expect{ rawImage != nil } == true
            autoreleasepool {
                rawImage?.colorSpace = CGColorSpace(name: CGColorSpace.displayP3 as CFString)
                expect{ rawImage?.tiffRepresentation(format: CIFormat.RGBA8) != nil } == true
                expect{ try rawImage?.writeTIFFRepresentation(to: tiffURL, format: CIFormat.RGBA8) }.toNot(throwError())
            }
            
            let parametersURL = URL(fileURLWithPath: parametersDirectory + "/raw.json")
            
            let parameters: String
            do {
                parameters = try String(contentsOf: parametersURL)
            } catch let error {
                XCTFail("\(error)")
                return
            }
            guard let appleRawParameters = AppleRawParameters.deserialize(from: parameters) else {
                XCTFail()
                return
            }
            
            autoreleasepool {
                expect{ try rawImage?.removeCA(from: tiffURL, takenAtFocal: 98, usingLensModel: "EF24", usingParameters: appleRawParameters) }.toNot(throwError())
            }
        }
    }
}


class AutoAlphaTests: XCTestCase {
    
    static let dropbox_root = NSHomeDirectory() + "/Dropbox (VR Holding BV)/"
    let dropBox: String = dropbox_root + "AA2Metalic_InOut/"
        
    func testAccuracy() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        
        /// preparations: these should be done once at the bootup and also everytime right after a new callibration
        var settings = Settings()
        settings.mcalibrationfolderpath = dropBox + "sample_shots/sd-797_20201014_123340_AA2/"
        
        // initiate a size estimator
        var actualSizeEstimator =  ActualSizeEstimator()
        //detect the machine's model
        actualSizeEstimator.detectMachineModel(withSettings: settings)
        
        let machineIntrinsicsJsonPathURL = URL(fileURLWithPath: dropBox + "MachinesModelList.json")
        if(!FileManager.default.fileExists(atPath: machineIntrinsicsJsonPathURL.path)){
            throw Error.dataNotFound(name:"MachinesModelList.json", path: machineIntrinsicsJsonPathURL.absoluteString)
        }
        try actualSizeEstimator.getMachineIntrinsics(from: machineIntrinsicsJsonPathURL)
        
        // build an AA2 object
        let aa2 = try AA2( actualSizeEstimator: &actualSizeEstimator, withSettings: settings)
        // change process flags if you'd like
        aa2.settings.saving_debug = true
        aa2.settings.discardPrevAlpha = false //true: 10ms->119ms(60s) -- false: 13ms->160ms(60s).
        aa2.settings.camera_preview_scaledown_factor = 6
        
        /// Action!
        // shoot the photo and point aa2 to its location. Also set tell it if there was a dock attached and the zoom level.
        let sampleBundle = dropBox + "sample_shots/fixture/acquired/"
        aa2.setCurrentDockType(dockType: .Fixture)
        aa2.mzoom = 0
        
        if aa2.settings.saving_debug {
            aa2.settings.DebugFolder = sampleBundle + "../inprogress/debug/"
        }
        
        let blackFlashImage_name: String = sampleBundle + "shot_on.jpg"
        let blackFlashImage = try! CGImage.load(withName: blackFlashImage_name)
        //    aa2.blackFlashImage = blackFlashImage?.convertToGrayScaleDiscardAlpha()
        aa2.blackFlashImage = blackFlashImage?.convertToGrayScaleDiscardAlpha()
        
        // generate the alpha channel
        var startTime = mach_absolute_time()
        aa2.buildAlpha()
        print("Building alpha took \(machToSeconds * Double(mach_absolute_time() - startTime)) secs.")
        
        // transfer the alpha to the user image
        let alphaMask = aa2.getAlpha()
        let BBRect = aa2.getBBRect()
        let imUser_name: String = sampleBundle + "../inprogress/fromRawCon_user8bit.tif"
        var userImg = try! CGImage.load(withName: imUser_name)
        userImg = userImg?.cropping(to: BBRect)
        startTime = mach_absolute_time()
        //    userImg = try? userImg?.setAlphaToAlphaFrom_accelerate(alphaMask)
        userImg = try! userImg?.setAlphaTo_accelerate(alphaMask)
        //    userImg = try userImg?.maskingAfterConvertingToMask(image: alphaMask) // TODO: continue with exploring .masking
        //    userImg = userImg?.masking(alphaMask)
        print("Transferring alpha took", (machToSeconds * Double(mach_absolute_time() - startTime)),"seconds.")
        try userImg!.writeViaCGImageDestination(fileName: aa2.settings.DebugFolder! + "userImg.tif")
    }
}
class aspectRatioTests: XCTestCase {
    
    static let dropbox_root = NSHomeDirectory() + "/Dropbox (VR Holding BV)/"
    let dropBoxTMP: String = dropbox_root + "AA2Metalic_InOut/TMP/"
        
    /// testing crop to aspect ratio method
    func testAccuracy() throws {
        var userImg = try! CGImage.load(withName: "/Users/sm/Desktop/Background-board-fullHD-01.png")
        
        //        userImg = try userImg.scaleToWidthViaAccelerate(960)!
        //        //    userImg = try userImg?.rotate(90)
        
        let w = CGFloat(userImg!.width)
        let h = CGFloat(userImg!.height)
        let C = CGPoint(x: w/2, y: h/2) // set a random center for the crop
        userImg = try userImg!.adaptAspectRatioTo(5/4, withCenterAt: C, andMarginOf: 0, withPaddingBeing: .notAllowed) // try CGFloat.pi/2 as the aspect ratio to see it fail!
        try userImg!.writeViaCGImageDestination(fileName: dropBoxTMP + "userImgWithARsetTo54.tif")
        
        userImg = try userImg!.scaleToWidthKeepAR_acc(toWidth: 1000)!
        try userImg!.writeViaCGImageDestination(fileName: dropBoxTMP + "userImgWithARsetTo43AfterWidthAltered54.tif")
        
    }
}
