//
//  CameraViewController.swift
//  PixellateFilter
//
//  Created by Kusal Rajapaksha on 2023-06-08.
//

import AVFoundation
import UIKit
import CoreImage

protocol CameraViewControllerDelegate : AnyObject{
    func addNewPaletteFromCamera(hexColorArray:[String])
}

class CameraViewController: UIViewController,UINavigationControllerDelegate,AVCaptureVideoDataOutputSampleBufferDelegate {
    
    weak var delegate: CameraViewControllerDelegate?
//    private var colorPickerType : ColorPickerType!
    private var captureSession: AVCaptureSession!
    private let previewLayer = AVCaptureVideoPreviewLayer()
   
    private let videoOutput = AVCaptureVideoDataOutput()
    
    private let backgroundView = UIImageView()  ///Frames coming from AVCaptureVideoDataOutputSampleBufferDelegate method are added to this view
    private let boxView = UIImageView()
    private var toggleButtonClicked = true
    private let output = AVCapturePhotoOutput()
    private var mask: maskView!
    
    private let ciPixellateFilterIndex = 200
    
    private var croppedImage: UIImage?
    private var viewWidth: CGFloat!
    private var viewHeight: CGFloat!
    private var palleteViewWidth: CGFloat!
    private var alwaysDiscardsLateVideoFrames: Bool!
    private var cameraPermissionGranted = false
    private var filteredImage : UIImage?   ///holding the pixellated image
    ///
    private let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
    
    private var palleteViewX: CGFloat = 0
    private var palleteViewY: CGFloat = 0
    
    private let filter =  CIFilter(name: "CIPixellate")
    private let resizeFilter = CIFilter(name:"CILanczosScaleTransform")!
    private let targetSize = CGSize(width:1000, height:300)
    
    private var isUIConfigured: Bool = false
    private var isDarkTheme: Bool = false
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
        if #available(iOS 12.0, *) {
            self.isDarkTheme = traitCollection.userInterfaceStyle == .dark ? true : false
        }else{
            self.isDarkTheme = false
        }
        configureSizes()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask{
        return .portrait
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
                    
            if #available(iOS 12.0, *) {
                if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
                    if traitCollection.userInterfaceStyle == .dark {
                        self.changeTheme(isDark: true)
                    }else{
                        self.changeTheme(isDark: false)
                    }
                }
            } else {
                // Fallback on earlier versions
            }
    }
    
    func configureSizes(){
        viewWidth = 373
        viewHeight = viewWidth / 10 * 3

    }
    
    private func addVideoOutput() {
        self.videoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange), AVVideoWidthKey as NSString : 640, AVVideoHeightKey as NSString : 480,AVVideoCompressionPropertiesKey as NSString: [
            AVVideoAverageBitRateKey: 100_000, // Reduced bitrate (in bits per second)
            AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
        ] as [String : Any]] as [String : Any]//[(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "my.image.handling.queue"))
        self.videoOutput.alwaysDiscardsLateVideoFrames = true
        if #available(iOS 13.0, *) {
            self.videoOutput.automaticallyConfiguresOutputBufferDimensions = true
        } else {
            // Fallback on earlier versions
        }
        
        self.captureSession.addOutput(self.videoOutput)
    }
    

    private func addPreviewLayer(){
        self.view.layer.addSublayer(self.previewLayer)
    }
    
    var rectangleLayer: CALayer!
    
    var rectangleOne: CALayer!
    var rectangleTwo: CALayer!
    var rectangleThree: CALayer!
    
    var palleteCALayers = [CALayer]()
    var numberOfPalletes: Int = 3
    
    var CIImageOriginX: CGFloat = 0
    var CIImageOriginY: CGFloat = 0
    
    private func setUpCamera(){
        
        rectangleLayer = CALayer()
        palleteViewX = self.view.center.x - viewWidth / 2
        palleteViewY = self.view.center.y - viewHeight / 2
        
        rectangleLayer.frame = CGRect(x: palleteViewX, y: palleteViewY, width: viewWidth, height: viewHeight)
        rectangleLayer.zPosition = previewLayer.zPosition + 1
        
        //--pallete layers
        rectangleOne = CALayer()
        rectangleTwo = CALayer()
        rectangleThree = CALayer()
        
    
        for i in 0..<30{
            let verticalIndex = i / 10
            let horizontalIndex = i % 10
            let layer = CALayer()
            layer.frame = CGRect(x: 0 + viewWidth/10 * CGFloat(horizontalIndex), y: 0 + viewHeight/3 * CGFloat(verticalIndex), width: viewWidth/10, height: viewHeight/3)
            layer.zPosition = rectangleLayer.zPosition + 1
            rectangleLayer.addSublayer(layer)
            palleteCALayers.append(layer)
        }
        

        //--adding layers
        previewLayer.addSublayer(rectangleLayer)

        
        CIImageOriginX = palleteViewX
        CIImageOriginY = palleteViewY
        
        print("KKK rectangleLayer frame: \(rectangleLayer.frame)")
        print("KKK CIImage Origin: \(CIImageOriginX),\(CIImageOriginY)")
        
        
        
        view.addSubview(backgroundView)
        setupBackgroundView()
        
        view.addSubview(palleteView)
        setupPalleteView()
        
        view.addSubview(boxView)
        setupBoxView()
        
        view.addSubview(shutterButton)
        setupShutterButton()
        
        view.addSubview(cancelButton)
        setupCancelButton()
        
        view.addSubview(toggleButton)
        setupToggleButton()
        
        view.addSubview(filteredImagePreviewView)
        setupFilteredImagePreviewView()
        
        view.addSubview(cellContainerFrameView)
        setupCellContainerFrame()
        
        captureSession = AVCaptureSession()
        
        
        if let device = AVCaptureDevice.default(for: .video){
            do{
                let input = try AVCaptureDeviceInput(device: device)
                if captureSession.canAddInput(input){
                    captureSession.addInput(input)
                }
                
                self.addVideoOutput()
                
                self.previewLayer.videoGravity = .resizeAspectFill
                self.previewLayer.session = captureSession
                DispatchQueue.global(qos: .background).async {
                    self.captureSession.startRunning()
                }
            }catch{
                print(error)
            }
        }
        
        self.isUIConfigured = true
    }
    
    private func changeTheme(isDark: Bool){
        if isDark{
            cellContainerFrameView.layer.borderColor = UIColor.black.cgColor
            frameTitleBar.backgroundColor = UIColor.black
            frameTitleBar.textColor = UIColor.white
            toggleButton.backgroundColor = UIColor.black
            toggleButton.setTitleColor(UIColor.white, for: .normal)
            cancelButton.backgroundColor = UIColor.black
            cancelButton.setTitleColor(UIColor.white, for: .normal)
            shutterButton.backgroundColor = UIColor.black
            shutterButton.setTitleColor(UIColor.white, for: .normal)
        }else{
            cellContainerFrameView.layer.borderColor = UIColor.white.cgColor
            frameTitleBar.backgroundColor = UIColor.white
            frameTitleBar.textColor = UIColor.black
            toggleButton.backgroundColor = UIColor.white
            toggleButton.setTitleColor(UIColor.black, for: .normal)
            cancelButton.backgroundColor = UIColor.white
            cancelButton.setTitleColor(UIColor.black, for: .normal)
            shutterButton.backgroundColor = UIColor.white
            shutterButton.setTitleColor(UIColor.black, for: .normal)
        }
    }
    
    private func checkCameraPermissions(){
        switch AVCaptureDevice.authorizationStatus(for: .video){
        case .notDetermined:
            //request
            AVCaptureDevice.requestAccess(for: .video){granted in
                guard granted else{
                    DispatchQueue.main.async {
                      // main thread commands should be coded inside this
                        self.dismiss(animated: true)
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.setUpCamera()
                    self.cameraPermissionGranted = true
                }
            }
        case .restricted:
            self.alertCameraAccessNeeded()
            self.dismiss(animated: true)
            
        case .denied:
            self.alertCameraAccessNeeded()
            self.dismiss(animated: true)
            
        case .authorized:
            setUpCamera()
        @unknown default:
            return
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.checkCameraPermissions()
        if self.isUIConfigured{
            self.changeTheme(isDark: isDarkTheme)
        }
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        print("KKK size \(size)")
        self.view.layoutIfNeeded()
        
        palleteViewX = size.width / 2 - viewWidth / 2
        palleteViewY = size.height / 2 - viewHeight / 2
        
        rectangleLayer.frame = CGRect(x: palleteViewX, y: palleteViewY, width: viewWidth, height: viewHeight)
    }
    
    func alertCameraAccessNeeded() {
        let settingsAppURL = URL(string: UIApplication.openSettingsURLString)!

        let alert = UIAlertController(
            title: "Need Camera Access",
            message: "Camera access is required to make full use of this app",
            preferredStyle: UIAlertController.Style.alert
        )
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: { (action) -> Void in
            self.dismiss(animated: true)
         })

        alert.addAction(cancelAction)
        alert.addAction(UIAlertAction(title: "Allow Camera", style: .cancel, handler: { (alert) -> Void in
            UIApplication.shared.open(settingsAppURL, options: [:], completionHandler: nil)
            self.dismiss(animated: true)
        }))

        present(alert, animated: true, completion: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.addPreviewLayer()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
       
    }
    
    private func updatePreviewLayer(layer: AVCaptureConnection, orientation: AVCaptureVideoOrientation) {
        layer.videoOrientation = orientation
        previewLayer.frame = self.view.bounds
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let connection =  self.previewLayer.connection  {

            let currentDevice: UIDevice = UIDevice.current

            let orientation: UIDeviceOrientation = currentDevice.orientation
            
            let previewLayerConnection : AVCaptureConnection = connection
            
            previewLayer.frame = self.view.bounds
            
            if previewLayerConnection.isVideoOrientationSupported {

                switch (orientation) {
                case .portrait: updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)
                case .landscapeRight: updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeLeft)
                case .landscapeLeft: updatePreviewLayer(layer: previewLayerConnection, orientation: .landscapeRight)
                case .portraitUpsideDown: updatePreviewLayer(layer: previewLayerConnection, orientation: .portraitUpsideDown)
                default: updatePreviewLayer(layer: previewLayerConnection, orientation: .portrait)

                }
            }

            
        }
    }
    
    func setupBackgroundView(){
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            backgroundView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            backgroundView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            backgroundView.widthAnchor.constraint(equalTo: view.widthAnchor),
            backgroundView.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
    }
    
    func setupShutterButton(){
        
        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.bottomAnchor,constant: -25),
            shutterButton.widthAnchor.constraint(equalToConstant: 50),
            shutterButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    func setupCancelButton(){
        
        NSLayoutConstraint.activate([
            cancelButton.trailingAnchor.constraint(equalTo: shutterButton.leadingAnchor,constant: -40),
            cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor,constant: -30),
            cancelButton.widthAnchor.constraint(equalToConstant: 100),
            cancelButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func setupToggleButton(){
        
        NSLayoutConstraint.activate([
            toggleButton.leadingAnchor.constraint(equalTo: shutterButton.trailingAnchor,constant: 40),
            toggleButton.bottomAnchor.constraint(equalTo: view.bottomAnchor,constant: -30),
            toggleButton.widthAnchor.constraint(equalToConstant: 100),
            toggleButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc func palleteModeSelect(){
        if toggleButtonClicked{
            toggleButton.setTitle("Indexed", for: .normal)
            toggleButtonClicked = false
        }
        else{
            toggleButton.setTitle("Visual", for: .normal)
            toggleButtonClicked = true
        }
    }
    
    @objc func cancelCameraFeed(){
        self.dismiss(animated: true,completion: nil)
        self.captureSession.stopRunning()
    }

    func setupBoxView(){
        boxView.translatesAutoresizingMaskIntoConstraints = false
        boxView.backgroundColor = .clear
        boxView.contentMode = .scaleAspectFit
        NSLayoutConstraint.activate([
            boxView.topAnchor.constraint(equalTo: view.topAnchor),
            boxView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            boxView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            boxView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }
    
    func setupPalleteView(){
        palleteView.translatesAutoresizingMaskIntoConstraints = false
        palleteView.backgroundColor = .clear
        
        NSLayoutConstraint.activate([
            palleteView.widthAnchor.constraint(equalToConstant: viewWidth),
            palleteView.heightAnchor.constraint(equalToConstant: viewHeight),
            palleteView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            palleteView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
    
    func setupFilteredImagePreviewView(){
        filteredImagePreviewView.translatesAutoresizingMaskIntoConstraints = false
        filteredImagePreviewView.contentMode = .scaleAspectFit
        
        NSLayoutConstraint.activate([
            filteredImagePreviewView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            filteredImagePreviewView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            filteredImagePreviewView.widthAnchor.constraint(equalToConstant: viewWidth),
            filteredImagePreviewView.heightAnchor.constraint(equalToConstant: viewHeight),
        ])
    }
    
    func setupCellContainerFrame(){
        ///Addidng "Color pallete" label to top of the cellContainerFrame
        cellContainerFrameView.addSubview(frameTitleBar)
        cellContainerFrameView.translatesAutoresizingMaskIntoConstraints = false
        cellContainerFrameView.layer.borderWidth = 5
        cellContainerFrameView.layer.cornerRadius = 8
        
        NSLayoutConstraint.activate([
            cellContainerFrameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cellContainerFrameView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            cellContainerFrameView.widthAnchor.constraint(equalToConstant: viewWidth+10),
            cellContainerFrameView.heightAnchor.constraint(equalToConstant:viewHeight+10),
            
            frameTitleBar.bottomAnchor.constraint(equalTo: cellContainerFrameView.topAnchor,constant: 8),
            frameTitleBar.widthAnchor.constraint(equalToConstant: viewWidth+10),
            frameTitleBar.heightAnchor.constraint(equalToConstant:40),
            
        ])
    }
    
    //MARK: UI elements
    lazy var palleteView : UIView = {
        let view = UIView()
        return view
    }()
    
    lazy var cellContainerFrameView : UIView = {
        let view = UIView()
        return view
    }()
    
    lazy var frameTitleBar : UILabel = {
        let label = UILabel()
        label.text = "Color palette"
        label.textAlignment = .center
        label.textColor = .black
        label.adjustsFontSizeToFitWidth = true
        label.layer.masksToBounds = true
        label.layer.cornerRadius = 10
        label.layer.maskedCorners = [.layerMinXMinYCorner,.layerMaxXMinYCorner]
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var filteredImagePreviewView : UIImageView = {
        let view = UIImageView()
        return view
    }()
    
    lazy var cancelButton: UIButton = {
        let btn = UIButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.backgroundColor = .white
        btn.tintColor = .white
        btn.layer.cornerRadius = 10
        btn.setTitle("Cancel", for: .normal)
        btn.setTitleColor(.black, for: .normal)
        btn.addTarget(self, action: #selector(cancelCameraFeed), for: .touchUpInside)
        return btn
    }()
    
    lazy var shutterButton: UIButton = {
        let btn = UIButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.layer.borderWidth = 4
        btn.backgroundColor = .white
        btn.layer.borderColor = UIColor.lightGray.cgColor
        btn.layer.cornerRadius = 25
        btn.addTarget(self, action: #selector(getColorsHexArrayFromCameraPhoto), for: .touchUpInside)
        return btn
    }()
    
    lazy var toggleButton: UIButton = {
        let btn = UIButton()
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("Visual", for: .normal)
        btn.backgroundColor = .white
        btn.tintColor = .white
        btn.layer.cornerRadius = 10
        btn.setTitleColor(.black, for: .normal)
        btn.addTarget(self, action: #selector(palleteModeSelect), for: .touchUpInside)
        return btn
    }()
   
    private let processingQueue = DispatchQueue(label: "com.example.processingQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
  
    private let renderingQueue = DispatchQueue(label: "com.example.renderingQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    private let concurrentQueue = DispatchQueue(label: "com.example.concurrentQueue",qos: .userInitiated, attributes: .concurrent)
    
    private let operationQueue = OperationQueue()
    private let processingOperationQueue = OperationQueue()
    
    let semaphore = DispatchSemaphore(value: 2)
        
    var frameCounter = 0
    var frameBuffer: [CIImage] = []
    
    var operationArray: [BlockOperation] = []

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCounter += 1
        if frameCounter % 3 != 0{
            return
        }else{
            frameCounter = 0
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        
        //---
        let operation1 = BlockOperation {
            self.processPixelBuffer(pixelBuffer)
        }

        let operation2 = BlockOperation {
            self.renderToACGImage()
        }

        operation2.addDependency(operation1)
        
        processingOperationQueue.addOperations([operation1,operation2], waitUntilFinished: true)
        
        processingOperationQueue.addBarrierBlock {
            self.processedCIImage = nil
        }
        
        if renderedCGImage == nil{
            return
        }
        

        for i in 0..<30 {
            let operation = BlockOperation {
                self.addColorsToCALayers(index: i)
            }
            operationArray.append(operation)
            
//            concurrentQueue.async { [self] in
//                addColorsToCALayers(index: i)
//            }
        }
//
        operationQueue.addOperations(operationArray, waitUntilFinished: true)
        operationQueue.addBarrierBlock {
            self.operationArray = []
        }
        
//
        
        
    }
    
    
    
    var processedCIImage: CIImage?
    
    func scaleDownImage(_ image: CIImage, scaleFactor: CGFloat) -> CIImage? {
        let filter = CIFilter(name: "CILanczosScaleTransform")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(scaleFactor, forKey: kCIInputScaleKey)
        filter?.setValue(1.0, forKey: kCIInputAspectRatioKey)

        return filter?.outputImage
    }
    
    private func processPixelBuffer(_ pixelBuffer: CVPixelBuffer){
        // Lock the buffer to ensure memory access
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        print("KKK ui device orientation: \(UIDevice.current.orientation.rawValue)")
        
        let initialCIImage = CIImage(cvPixelBuffer: pixelBuffer, options: [CIImageOption.applyOrientationProperty: true]).oriented(.right)
        print("KKK initialCIImage frame: \(initialCIImage.extent)")
 
        let croppedCIImage = resizeAndCropCIImage(inputCIImage: initialCIImage)
        
        guard let downScaledCIImage = scaleDownImage(croppedCIImage, scaleFactor: 0.5) else{
            return
        }
        print("KKK downScaledCIImage frame: \(downScaledCIImage.extent)")
        processedCIImage = downScaledCIImage
    }
    
    //--new functions draw to layers
    var renderedCGImage : CGImage!
    
    func renderToACGImage(){
        guard let croppedCIImage = processedCIImage else {
            return
        }
        
        guard let cgImage = context.createCGImage(croppedCIImage, from: croppedCIImage.extent) else {
            return
        }
    
        renderedCGImage = cgImage

        print("KKK cgImage size: \(renderedCGImage.width), \(renderedCGImage.height)")
    }
    
    func addColorsToCALayers(index: Int){
        let rect = CGRect(x: 0 + CGFloat(renderedCGImage.width)/10 * CGFloat(index % 10), y: 0 + CGFloat(renderedCGImage.height)/3 * CGFloat(index / 10), width: CGFloat(renderedCGImage.width)/10, height: CGFloat(renderedCGImage.height)/3)
        
        DispatchQueue.main.async {[self] in
            palleteCALayers[index].backgroundColor = getProminentColors(inputCGImage: renderedCGImage, rectangleRect: rect)?.cgColor
        }
    }
    
    func downsampleCGImage(image: CGImage, to size: CGSize) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            // Create the bitmap context
            guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return nil
            }
            
            // Set the interpolation quality to high for better downsampled image quality
            context.interpolationQuality = .high
            
            // Calculate the aspect ratio to determine the scaling factor
            let scale = max(size.width / CGFloat(image.width), size.height / CGFloat(image.height))
            
            // Calculate the new size
            let scaledSize = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
            
            // Draw the downsampled image to the bitmap context
            context.draw(image, in: CGRect(origin: .zero, size: scaledSize))
            
            // Get the final downscaled image
            let downscaledImage = context.makeImage()
            
            return downscaledImage
    }

    //--
    
    //--functions
    
    func resizeAndCropCIImage(inputCIImage: CIImage) -> CIImage{
        let targetWidth = 414.00
        let targetHeight = 896.00
        
        let resizedImage = inputCIImage.transformed(by: CGAffineTransform(scaleX: targetWidth / inputCIImage.extent.width, y: targetHeight / inputCIImage.extent.height))
        
        print("KKK resized image: \(resizedImage.extent)")
        
        let cropFrame = CGRect(x: CIImageOriginX , y: CIImageOriginY, width: viewWidth , height: viewHeight)
        let croppedCIImage = resizedImage.cropped(to: cropFrame)
        print("KKK image size \(croppedCIImage.extent)")
        return croppedCIImage
    }
    
    func applyFilters(inputCIImage: CIImage) -> CIImage?{
        /// Compute scale and corrective aspect ratio
        let scale = targetSize.height / (inputCIImage.extent.height)
        let aspectRatio = targetSize.width/((inputCIImage.extent.width) * scale)

        /// Apply resizing
        resizeFilter.setValue(inputCIImage, forKey: kCIInputImageKey)
        resizeFilter.setValue(scale, forKey: kCIInputScaleKey)
        resizeFilter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)

        print("KKK resized frame: \(resizeFilter.outputImage?.extent)")

        self.filter?.setValue(resizeFilter.outputImage, forKey: kCIInputImageKey)
        self.filter?.setValue(100, forKey: kCIInputScaleKey)

        
        return filter?.outputImage
    }
    
    func getProminentColors(inputCGImage:CGImage, rectangleRect: CGRect) -> UIColor?{
        guard let context = CGContext(data: nil,
                                         width: inputCGImage.width,
                                         height: inputCGImage.height,
                                         bitsPerComponent: 8,
                                         bytesPerRow: inputCGImage.bytesPerRow,
                                         space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
               return nil
           }

           // Draw the CGImage to the context
           context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: inputCGImage.width, height: inputCGImage.height))

           // Extract pixel data from the context
           guard let data = context.data else {
               return nil
           }

           let buffer = data.assumingMemoryBound(to: UInt8.self)

           // Initialize a dictionary to store color counts
           var colorCounts: [UIColor: Int] = [:]

           for y in Int(rectangleRect.origin.y) ..< Int(rectangleRect.maxY) {
               for x in Int(rectangleRect.origin.x) ..< Int(rectangleRect.maxX) {
                   let offset = (y * inputCGImage.bytesPerRow) + (x * 4) // Each pixel is represented by 4 bytes (RGBA)
                   let red = CGFloat(buffer[offset]) / 255.0
                   let green = CGFloat(buffer[offset + 1]) / 255.0
                   let blue = CGFloat(buffer[offset + 2]) / 255.0

                   let color = UIColor(red: red, green: green, blue: blue, alpha: 1.0)

                   if let count = colorCounts[color] {
                       colorCounts[color] = count + 1
                   } else {
                       colorCounts[color] = 1
                   }
               }
           }

           // Find the color with the highest count
           let sortedColors = colorCounts.sorted { $0.value > $1.value }
           if let mostFrequentColor = sortedColors.first?.key {
               return mostFrequentColor
           }

           return nil
        
    }
    
    func renderCIImageToScreen(inputCIImage: CIImage){
        guard let renderedImage = context.createCGImage(inputCIImage, from: inputCIImage.extent) else {
            return
        }
        
        print("KKK frame cg: \(renderedImage.width), \(renderedImage.height)")
                // Perform UI updates on the main thread
        DispatchQueue.main.async {
            // Display the filtered image in an image view or layer
            self.rectangleLayer.contentsGravity = .resizeAspectFill
            self.rectangleLayer.contents = renderedImage
        }
    }
    
    //--

    
    func rotateCIImage(_ image: CIImage, angle: CGFloat) -> CIImage? {
        let transform = CGAffineTransform(rotationAngle: angle)
        let rotatedImage = image.transformed(by: transform)
        return rotatedImage
    }
    
    @objc func getColorsHexArrayFromCameraPhoto(){
        var colorHexCodeArray = [String]()
        for i in 1...3{
            let y_point = Int(100)*(2*i-1)
            for j in 1...10{
                let x_point = Int(100)*(2*j-1)
//                let color : UIColor = croppedImage!.pixelColor(x: x_point, y: y_point)
//                let colorHex  = convertColorToHex(color: color)
//                colorHexCodeArray.append(colorHex)
            }
        }
        self.delegate?.addNewPaletteFromCamera(hexColorArray: colorHexCodeArray)
        captureSession.stopRunning()
        self.dismiss(animated: true,completion: nil)
    }

}

class maskView: UIView{
    let centralView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addSubview(self.centralView)
        self.backgroundColor = .clear
        self.centralView.backgroundColor = .red
        self.centralView.clipsToBounds = true
        self.centralView.center = self.center
        self.centralView.bounds.size = frame.size
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
}

extension UIView {

    func snapshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, true, UIScreen.main.scale)
        self.layer.render(in: UIGraphicsGetCurrentContext()!)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }
}

extension UIImage {
    func imageWithImage(image: UIImage, croppedTo rect: CGRect) -> UIImage {

        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()

        let drawRect = CGRect(x: -rect.origin.x, y: -rect.origin.y,
                              width: image.size.width, height: image.size.height)

        context?.clip(to: CGRect(x: 0, y: 0,
                                 width: rect.size.width, height: rect.size.height))

        image.draw(in: drawRect)

        let subImage = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()
        return subImage!
    }
}

/*
DispatchQueue.main.async{ [self] in
    ///get frames from AVCaptureVideoDataOutputSampleBufferDelegate
    guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else{
        debugPrint("Unable to get image from sample buffer")
        return
    }
    
    ///convert image buffer to CI Image
    let currentCIImage = CIImage(cvPixelBuffer: frame)
    let rotatedImage = rotateCIImage(currentCIImage, angle: -CGFloat.pi / 2)
    
    ///convert CI Image to UI image
    var currentUIImage : UIImage?
    if let cgimg = context.createCGImage(rotatedImage!,from: rotatedImage!.extent){
        currentUIImage = UIImage(cgImage: cgimg)
    }
    
    
    if toggleButtonClicked{
        ///Add a mask to UI Image and get a snap of pallete view
        self.boxView.image = currentUIImage
        mask = maskView(frame: CGRect(x: 0, y: 0, width: CGFloat(viewWidth), height: CGFloat(viewHeight)))
        mask.centralView.center = view.center
        boxView.mask = mask
        boxView.layer.masksToBounds = true
        palleteView.center = mask.centralView.center
        palleteView.addSubview(boxView)
        
        let snapImage = palleteView.snapshot()!

        ///convert snap -> cg image -> ci image
        guard let currentCGImage = snapImage.cgImage else { return }
        ///doubles the ui image size
        let tempCIImage = CIImage(cgImage: currentCGImage)
        
        ///resize CI Image to fixed size before adding CI Filter
        let resizeFilter = CIFilter(name:"CILanczosScaleTransform")!
        let targetSize = CGSize(width:2000, height:600)

        ///Compute scale and corrective aspect ratio
        let scale = targetSize.height / (tempCIImage.extent.height)
        let aspectRatio = targetSize.width/((tempCIImage.extent.width) * scale)

        /// Apply resizing
        resizeFilter.setValue(tempCIImage, forKey: kCIInputImageKey)
        resizeFilter.setValue(scale, forKey: kCIInputScaleKey)
        resizeFilter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
        let tempCIImageResized = resizeFilter.outputImage!
        
        ///add pixellate CI filter
        
        let filter = CIFilter(name: "CIPixellate")
        filter!.setValue(tempCIImageResized.self, forKey: kCIInputImageKey)
        filter!.setValue(ciPixellateFilterIndex, forKey: kCIInputScaleKey)
        
        guard let filterCIOutput = filter!.outputImage else { return }
        
        ///filtered CI image -> UI Image
        if let filtercgimg = context.createCGImage(filterCIOutput,from: filterCIOutput.extent){
            filteredImage = UIImage(cgImage: filtercgimg)
            croppedImage =  filteredImage!.imageWithImage(image: filteredImage!, croppedTo: CGRect(x: 50, y: 150, width: 2000, height: 600))
            filteredImagePreviewView.image = croppedImage!
            
        }
    }
    else{
        guard let currentCGImage = currentUIImage?.cgImage else { return }
        ///doubles the ui image size
        let tempCIImage = CIImage(cgImage: currentCGImage)

        ///resize CI Image to fixed size before adding CI Filter
        let resizeFilter = CIFilter(name:"CILanczosScaleTransform")!
        let targetSize = CGSize(width:2000, height:600)

        ///Compute scale and corrective aspect ratio
        let scale = targetSize.height / (tempCIImage.extent.height)
        let aspectRatio = targetSize.width/((tempCIImage.extent.width) * scale)

        /// Apply resizing
        resizeFilter.setValue(tempCIImage, forKey: kCIInputImageKey)
        resizeFilter.setValue(scale, forKey: kCIInputScaleKey)
        resizeFilter.setValue(aspectRatio, forKey: kCIInputAspectRatioKey)
        let tempCIImageResized = resizeFilter.outputImage!

        ///add pixellate CI filter

        let filter = CIFilter(name: "CIPixellate")
        filter!.setValue(tempCIImageResized.self, forKey: kCIInputImageKey)
        filter!.setValue(ciPixellateFilterIndex, forKey: kCIInputScaleKey)

        guard let filterCIOutput = filter!.outputImage else { return }

        ///filtered CI image -> UI Image
        if let filtercgimg = context.createCGImage(filterCIOutput,from: filterCIOutput.extent){
            filteredImage = UIImage(cgImage: filtercgimg)
            croppedImage =  filteredImage!.imageWithImage(image: filteredImage!, croppedTo: CGRect(x: 50, y: 150, width: 2000, height: 600))
            filteredImagePreviewView.image = croppedImage!
        }
    }
}

func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
    
    // Figure out what our orientation is, and use that to form the rectangle
    var newSize: CGSize
    newSize = CGSize(width: targetSize.width, height: targetSize.height)
    
    // This is the rect that we've calculated out and this is what is actually used below
    let rect = CGRect(origin: .zero, size: newSize)
    
    // Actually do the resizing to the rect using the ImageContext stuff
    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    image.draw(in: rect)
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return newImage
}
*/



