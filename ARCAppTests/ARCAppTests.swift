//
//  ARCAppTests.swift
//  ARCAppTests
//
/

import XCTest
import Nimble
@testable import AppleRawConverter

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
