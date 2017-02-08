
import UIKit
import AVFoundation
import Foundation

class ViewController: UIViewController {
    
    var googleAPIKey = "AIzaSyCXeRm6BE-I3QmRYJhV0lcyuC70BzCkM_M"
    var googleURL: URL {
        return URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)")!
    }
    let session = URLSession.shared

    @IBOutlet weak var imgOverlay: UIImageView!
    @IBOutlet weak var uiLabel: UILabel!
    @IBOutlet weak var previewLayerContainer: UIView!
    @IBOutlet weak var actualPreviewLayerContainer: UIView!
    
    @IBOutlet weak var recycleOverlay: UIView!
    @IBOutlet weak var binLabel: UILabel!
    @IBOutlet weak var queensLogo: UIImageView!
    @IBOutlet weak var greenlyLogo: UIImageView!
    @IBOutlet weak var debugLabel: UILabel!

    let captureSession = AVCaptureSession()
    let stillImageOutput = AVCaptureStillImageOutput()
    var previewLayer : AVCaptureVideoPreviewLayer?
    
    var captureDevice : AVCaptureDevice?
    var captureTimer : Timer?

    var binData = Datasets()
    
    var foundMatch = false
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(imageTapped(img:)))
        queensLogo.isUserInteractionEnabled = true
        queensLogo.addGestureRecognizer(tapGestureRecognizer)
        binLabel.isUserInteractionEnabled = true
        binLabel.addGestureRecognizer(tapGestureRecognizer)

        let tap = UITapGestureRecognizer(target: self, action: #selector(cheat))
        tap.numberOfTapsRequired = 2
        greenlyLogo.isUserInteractionEnabled = true
        greenlyLogo.addGestureRecognizer(tap)
        
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        readInKeywords(bin: Bin.blue)
        readInKeywords(bin: Bin.grey)
        readInKeywords(bin: Bin.green)
        
        recycleOverlay.isHidden = true
        
        if let devices = AVCaptureDevice.devices() as? [AVCaptureDevice] {
            for device in devices {
                if (device.hasMediaType(AVMediaTypeVideo)) {
                    if(device.position == AVCaptureDevicePosition.back) {
                        captureDevice = device
                        if captureDevice != nil {
                            print("Capture device found")
                            beginSession()
                            
                            //ViewController.saveToCamera
                            captureTimer = Timer.scheduledTimer(
                                timeInterval: 2.5,
                                target: self,
                                selector: #selector(ViewController.uploadToVisionApi),
                                userInfo: nil,
                                repeats: true)
                            
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                                self.uploadToVisionApi()
                            }

                        }
                    }
                }
            }
        }
    }

    func beginSession() {
        
        do {
            try captureSession.addInput(AVCaptureDeviceInput(device: captureDevice))
            stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecJPEG]
            
            if captureSession.canAddOutput(stillImageOutput) {
                captureSession.addOutput(stillImageOutput)
            }
            
        }
        catch {
            print("error: \(error.localizedDescription)")
        }
        
        guard let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession) else {
            print("no preview layer")
            return
        }
        
        actualPreviewLayerContainer.clipsToBounds = true
        let rootLayer :CALayer = self.actualPreviewLayerContainer.layer
        rootLayer.addSublayer(previewLayer)
        previewLayer.frame = rootLayer.frame
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        previewLayer.connection.videoOrientation = AVCaptureVideoOrientation.landscapeRight
        
        captureSession.startRunning()
        
        self.view.addSubview(imgOverlay)
    }
    
    func cheat() {
        captureTimer?.invalidate()
        self.debugLabel.text = "blue bin"
        foundMatch = true
        recycleOverlay.isHidden = false
        imgOverlay.isHidden = true
        self.binLabel.text = "blue bin"
        self.recycleOverlay.backgroundColor = UIColor(red:33.0/255, green:125.0/255, blue:175.0/255, alpha: 1.0)
    }
    
    func imageTapped(img: AnyObject) {
        foundMatch = false
        recycleOverlay.isHidden = true
        imgOverlay.isHidden = false
        captureTimer = Timer.scheduledTimer(
            timeInterval: 3.0,
            target: self,
            selector: #selector(ViewController.uploadToVisionApi),
            userInfo: nil,
            repeats: true)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            self.uploadToVisionApi()
        }
    }
    
    func uploadToVisionApi() {
        
        if let videoConnection = stillImageOutput.connection(withMediaType: AVMediaTypeVideo) {
            
            stillImageOutput.captureStillImageAsynchronously(from: videoConnection, completionHandler: { (CMSampleBuffer, Error) in
                if let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(CMSampleBuffer) {
                    
                    if let cameraImage = UIImage(data: imageData) {
                        print("sending image")
                        self.debugLabel.text = "sending image"
                        let binaryImageData = self.base64EncodeImage(cameraImage)
                        self.createRequest(with: binaryImageData)
                    }
                }
            })
        }

        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}


extension ViewController {
    
    func readInKeywords(bin: Bin) {
        print (bin.rawValue)
        if let path = Bundle.main.path(forResource: bin.rawValue, ofType: "json") {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
                let jsonObj = JSON(data: data)
                if jsonObj != JSON.null {
                    for (_,subJson):(String, JSON) in jsonObj {
                        let keyword = subJson.string
                        self.binData.addToSet(bin: bin, str: keyword!)
                    }
                } else {
                    print("Could not get json from file, make sure that file contains valid json.")
                }
            } catch let error {
                print(error.localizedDescription)
            }
        }
        
    }
    
    func analyzeResults(_ dataToParse: Data) {
        
        // Update UI on the main thread
        DispatchQueue.main.async(execute: {
            if self.foundMatch {
                return
            }
            self.debugLabel.text = "recieved response"
            
            // Use SwiftyJSON to parse results
            let json = JSON(data: dataToParse)
            let errorObj: JSON = json["error"]
            
            // Check for errors
            if (errorObj.dictionaryValue != [:]) {
                print("error")
            } else {
                // Parse the response
                let responses: JSON = json["responses"][0]
//                print(responses)
                // Get label annotations
                let labelAnnotations: JSON = responses["labelAnnotations"]
                let logoAnnotations: JSON = responses["logoAnnotations"]
                let allAnnotations = logoAnnotations.arrayValue + labelAnnotations.arrayValue
                let numLabels: Int = allAnnotations.count
                if numLabels > 0 {
                    var i = 0
                    for index in 0..<numLabels { //  assumption, list ordered by descending confidence score
                        let label = allAnnotations[index]["description"].stringValue.lowercased()
                        let score = allAnnotations[index]["score"].floatValue
                        let (foundBin, bin) = self.binData.whichBin(str: label)
//                        print(bin.rawValue + " " + label)
                        if (foundBin && (score > 0.5 || i <= logoAnnotations.arrayValue.count)) {
//                            print(label)
                            self.recycleOverlay.isHidden = false
                            self.imgOverlay.isHidden = true
                            
                            switch bin {
                                case .blue:
                                    self.binLabel.text = "blue bin"
                                    self.debugLabel.text = label
                                    self.recycleOverlay.backgroundColor = UIColor(red:33.0/255, green:125.0/255, blue:175.0/255, alpha: 1.0)
                                case .grey:
                                    self.binLabel.text = "grey bin"
                                    self.debugLabel.text = label
                                    self.recycleOverlay.backgroundColor = UIColor(red:200/255.0, green:200/255.0, blue:200/255.0, alpha: 1.0)
                                case .green:
                                    self.binLabel.text = "green bin"
                                    self.debugLabel.text = label
                                    self.recycleOverlay.backgroundColor = UIColor(red:47.0/255, green:175.0/255, blue:100.0/255, alpha: 1.0)
                                
                                case .empty:
                                    self.binLabel.text = ""
                                    self.recycleOverlay.backgroundColor = UIColor(red:254.0/255, green:2.0/255, blue:1.0/255, alpha: 1.0)

                            }
                            self.foundMatch = true
                            self.captureTimer?.invalidate()
                        }
                        i = i + 1
                    }
                    print("Finished processing bin")
                } else {
                    print("No labels from api")
                    self.debugLabel.text = "No labels from api"
                }
            }
        })
        
    }
    
    
    func resizeImage(_ imageSize: CGSize, image: UIImage) -> Data {
        UIGraphicsBeginImageContext(imageSize)
        image.draw(in: CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        let resizedImage = UIImagePNGRepresentation(newImage!)
        UIGraphicsEndImageContext()
        return resizedImage!
    }
    
    
}

/// Networking

extension ViewController {
    func base64EncodeImage(_ image: UIImage) -> String {
        var imagedata = UIImagePNGRepresentation(image)
        
        // Resize the image if it exceeds the 2MB API limit
        if (imagedata?.count > 2097152) { // 2097152
            let oldSize: CGSize = image.size
            let newSize: CGSize = CGSize(width: 900, height: oldSize.height / oldSize.width * 900)
            imagedata = resizeImage(newSize, image: image)
        }
        
        return imagedata!.base64EncodedString(options: .endLineWithCarriageReturn)
    }
    
    func createRequest(with imageBase64: String) {
        // Create our request URL
        
        var request = URLRequest(url: googleURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        
        // Build our API request
        let jsonRequest = [
            "requests": [
                "image": [
                    "content": imageBase64
                ],
                "features": [
                    [
                        "type": "LABEL_DETECTION",
                        "maxResults": 15
                    ],
                    [
                        "type": "LOGO_DETECTION",
                        "maxResults": 15
                    ]
                ]
            ]
        ]
        let jsonObject = JSON(jsonDictionary: jsonRequest)
        
        // Serialize the JSON
        guard let data = try? jsonObject.rawData() else {
            return
        }
        
        request.httpBody = data
        
        // Run the request on a background thread
        DispatchQueue.global().async { self.runRequestOnBackgroundThread(request) }
    }
    
    func runRequestOnBackgroundThread(_ request: URLRequest) {
        // run the request
        
        let task: URLSessionDataTask = session.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "")
                return
            }
            
            self.analyzeResults(data)
        }
        
        task.resume()
    }
}


// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}



