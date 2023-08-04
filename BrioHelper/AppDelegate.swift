//
//  AppDelegate.swift
//  BrioHelper
//
//  Created by Lev Sokolov on 2023-08-03.
//

import Cocoa
import AVFoundation

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    static var shared: AppDelegate { NSApplication.shared.delegate as! AppDelegate }
    
    var statusBarItem: NSStatusItem!
    
    var onDeviceSelected: ((AVCaptureDevice) -> Void)?
    var onFormatSelected: ((AvailableFormat) -> Void)?
    var onRefreshSelected: (() -> Void)?
    var onActiveSelected: ((Bool) -> Void)?
    
    private let devicesMenuItem = NSMenuItem(title: "Cameras", action: nil, keyEquivalent: "")
    private let formatsMenuItem = NSMenuItem(title: "Formats", action: nil, keyEquivalent: "")
    private var activeMenuItem: NSMenuItem!

    private var devices: [AVCaptureDevice] = []
    private var selectedDevice: AVCaptureDevice?
    private var formats: [AvailableFormat] = []
    private var selectedFormat: AvailableFormat?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button,
            let image = NSImage(named: NSImage.Name("hd")) {
            image.isTemplate = true
            button.image = image
        }
        
        let menu = NSMenu()
        
        let devicesMenu = NSMenu()
        devicesMenuItem.submenu = devicesMenu
        devicesMenu.delegate = self
        menu.addItem(devicesMenuItem)
        
        let formatsMenu = NSMenu()
        formatsMenuItem.submenu = formatsMenu
        formatsMenu.delegate = self
        menu.addItem(formatsMenuItem)
        
        menu.addItem(NSMenuItem(title: "Refresh Device List", action: #selector(refreshSelected), keyEquivalent: "r"))
        
        activeMenuItem = NSMenuItem(title: "Active", action: #selector(activeSelected), keyEquivalent: "")
        menu.addItem(activeMenuItem)
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitClicked), keyEquivalent: "q"))
        
        statusBarItem.menu = menu
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func handleDeviceList(_ devices: [AVCaptureDevice], selectedDevice: AVCaptureDevice? = nil) {
        self.devices = devices
        self.selectedDevice = selectedDevice
    }
    
    func handleFormatList(_ formats: [AvailableFormat], selectedFormat: AvailableFormat? = nil) {
        self.formats = formats
        self.selectedFormat = selectedFormat
    }
    
    func handleCurrentActiveState(_ active: Bool) {
        activeMenuItem.state = active ? .on : .off
    }
    
    // MARK: -

    @objc
    private func quitClicked(_ sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }
    
    @objc
    private func refreshSelected(_ sender: AnyObject) {
        onRefreshSelected?()
    }
    
    @objc
    private func activeSelected(_ sender: AnyObject) {
        onActiveSelected?(activeMenuItem.state == .off)
    }
    
    @objc
    private func deviceSelected(_ sender: NSMenuItem) {
        if let device = sender.representedObject as? AVCaptureDevice {
            print("Selected device: \(device.localizedName)")
            onDeviceSelected?(device)
        }
    }
    
    @objc
    private func formatSelected(_ sender: NSMenuItem) {
        if let format = sender.representedObject as? AvailableFormat {
            print("Selected format: \(format.description)")
            onFormatSelected?(format)
        }
    }
    
    private func populateDevicesMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        for device in devices {
            let item = NSMenuItem(title: device.localizedName, action: #selector(deviceSelected), keyEquivalent: "")
            item.representedObject = device
            item.state = device == selectedDevice ? .on : .off
            menu.addItem(item)
        }
    }
    
    private func populateFormatsMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        for format in formats {
            let item = NSMenuItem(title: format.description, action: #selector(formatSelected), keyEquivalent: "")
            item.representedObject = format
            item.state = format == selectedFormat ? .on : .off
            menu.addItem(item)
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if menu == devicesMenuItem.submenu {
            populateDevicesMenu(menu)
        } else if menu == formatsMenuItem.submenu {
            populateFormatsMenu(menu)
        }
    }
}