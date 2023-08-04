//
//  ViewController.swift
//  BrioHelper
//
//  Created by Lev Sokolov on 2023-08-03.
//

import Cocoa
import AVFoundation
import CoreMediaIO

class ViewController: NSViewController {

    private let viewModel = ViewModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AppDelegate.shared.onDeviceSelected = { [weak self] device in
            self?.viewModel.handleCameraSelection(device: device)
        }
        
        AppDelegate.shared.onFormatSelected = { [weak self] format in
            self?.viewModel.handleFormatSelection(format: format)
        }
        
        AppDelegate.shared.onRefreshSelected = { [weak self] in
            self?.viewModel.handleRefreshDevicesSelection()
        }
        
        AppDelegate.shared.onActiveSelected = { [weak self] active in
            self?.viewModel.handleIsActiveChange(active: active)
        }
        
        viewModel.onDevicesAvailable = { devices, selectedDevice in
            AppDelegate.shared.handleDeviceList(devices, selectedDevice: selectedDevice)
        }
        
        viewModel.onFormatsAvailable = { formats, selectedFormat in
            AppDelegate.shared.handleFormatList(formats, selectedFormat: selectedFormat)
        }
        
        viewModel.onActiveAvailable = { isActive in
            AppDelegate.shared.handleCurrentActiveState(isActive)
        }
        
        viewModel.handleViewDidLoad()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

class ViewModel: NSObject {
    
    var onDevicesAvailable: (([AVCaptureDevice], AVCaptureDevice?) -> Void)?
    var onFormatsAvailable: (([AvailableFormat], AvailableFormat?) -> Void)?
    var onActiveAvailable: ((Bool) -> Void)?
    
    private var targetDeviceId: String? {
        get { UserDefaults.standard.string(forKey: "target-camera") }
        set { UserDefaults.standard.set(newValue, forKey: "target-camera") }
    }
    
    private var targetFormat: AvailableFormat? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "target-format") else { return nil }
            return try? JSONDecoder().decode(AvailableFormat.self, from: data)
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: "target-format")
        }
    }
    
    private var isActiveStored: Bool {
        get { UserDefaults.standard.bool(forKey: "is-active") }
        set { UserDefaults.standard.set(newValue, forKey: "is-active") }
    }
    
    private var devices: [AVCaptureDevice] = [] {
        didSet { onDevicesAvailable?(devices, selectedDevice) }
    }
    
    private var selectedDevice: AVCaptureDevice? {
        didSet { onDevicesAvailable?(devices, selectedDevice) }
    }
    
    private var formats: [AvailableFormat] = [] {
        didSet { onFormatsAvailable?(formats, selectedFormat) }
    }
    
    private var selectedFormat: AvailableFormat? {
        didSet { onFormatsAvailable?(formats, selectedFormat) }
    }
    
    private var camera: Camera?
    
    private var isActive: Bool = true
    
    override init() {
        super.init()
    }
    
    func handleViewDidLoad() {
        isActive = isActiveStored
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.onActiveAvailable?(self.isActive)
        }
        
        handleRefreshDevicesSelection()
    }
    
    func handleCameraSelection(device: AVCaptureDevice) {
        targetDeviceId = device.uniqueID
        selectedDevice = device
        processCamera(with: device)
        
        try? reactivateFormats(of: device)
    }
    
    func handleRefreshDevicesSelection() {
        updateDeviceList()
        processCurrentCamera()
    }
    
    func handleFormatSelection(format: AvailableFormat) {
        targetFormat = format
        selectedFormat = format
        
        processCurrentCamera()
    }
    
    func handleIsActiveChange(active: Bool) {
        print("handleIsActiveChange: \(active)")
        
        isActive = active
        isActiveStored = active
        
        if active {
            processCurrentCamera()
        }
        else {
            camera = nil
        }
        
        onActiveAvailable?(active)
    }
    
    // MARK: -
    
    private func updateDeviceList() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
                mediaType: .video, position: .unspecified)
        
        devices = discoverySession.devices
    }
    
    private func processCurrentCamera() {
        if let targetDeviceId, let device = devices.first(where: { $0.uniqueID == targetDeviceId }) {
            selectedDevice = device
            processCamera(with: device)
        }
    }
    
    private func processCamera(with device: AVCaptureDevice) {
        listFormats(of: device)
        
        guard isActive else { return }
        
        let checkIfActive: (Camera) -> Void = { camera in
            guard camera.isOn() else { return }
            
            try? self.reactivateFormats(of: device)
        }
        
        let camera = Camera(captureDevice: device) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                guard let camera = self?.camera else { return }
                
                checkIfActive(camera)
            }
        }
        
        checkIfActive(camera)
        
        self.camera = camera
    }
    
    private func listFormats(of videoDevice: AVCaptureDevice) {
        formats = videoDevice.availableFormats
        
        if selectedFormat == nil, let bestFormat = videoDevice.bestFormat {
            selectedFormat = AvailableFormat(avFormat: bestFormat)
        }
    }
    
    private func reactivateFormats(of videoDevice: AVCaptureDevice) throws {
        
        let targetFormat: AVCaptureDevice.Format
        
        if let selectedFormat, let avFormat = videoDevice.findFormat(with: selectedFormat) {
            targetFormat = avFormat
        }
        else if let bestFormat = videoDevice.bestFormat {
            targetFormat = bestFormat
        }
        else {
            return
        }
        
        print("Best format: \(targetFormat)")
        
        if videoDevice.activeFormat == targetFormat {
            print("Best format is already set")
            return
        }
        
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.activeFormat = targetFormat
            videoDevice.unlockForConfiguration()
        } catch {
            print("Error setting format: \(error)")
        }
        
        let session = AVCaptureSession()
        
        session.startRunning()
        session.stopRunning()
    }
}

struct AvailableFormat: Codable, Equatable {
    let width: Int32
    let height: Int32
    let maxFPS: Float64
    let description: String
}

extension AvailableFormat {
    init(avFormat: AVCaptureDevice.Format) {
        let dimensions = CMVideoFormatDescriptionGetDimensions(avFormat.formatDescription)
        let maxFPS = avFormat.maxFPS
        let description = avFormat.description
        
        self.init(width: dimensions.width,
                  height: dimensions.height,
                  maxFPS: maxFPS,
                  description: description)
    }
}

extension AVCaptureDevice.Format {
    var dimensions: CMVideoDimensions {
        CMVideoFormatDescriptionGetDimensions(self.formatDescription)
    }
    
    var maxFPS: Float64 {
        videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate })?.maxFrameRate ?? 0
    }
}

extension AVCaptureDevice {
    func findFormat(with: AvailableFormat) -> Format? {
        return formats.first(where: { $0.dimensions.width == with.width && $0.dimensions.height == with.height })
    }
    
    var availableFormats: [AvailableFormat] {
        var availableFormats: [AvailableFormat] = []
        
        for format in formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let maxFPS = format.maxFPS
            let description = format.description
            
            let availableFormat = AvailableFormat(width: dimensions.width,
                                                  height: dimensions.height,
                                                  maxFPS: maxFPS,
                                                  description: description)
            
            availableFormats.append(availableFormat)
        }
        
        return availableFormats
    }
    
    var bestFormat: AVCaptureDevice.Format? {
        var bestFormat: AVCaptureDevice.Format? = nil
        var bestDimensions = CMVideoDimensions(width: 0, height: 0)
        
        for format in formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            if dimensions.width > bestDimensions.width && dimensions.height > bestDimensions.height {
                bestFormat = format
                bestDimensions = dimensions
            }
        }
        
        return bestFormat
    }
}
