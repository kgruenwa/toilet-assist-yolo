//
//  CameraPreview.swift
//  toilet-assist-yolo
//
//  Created by Katharina Grünwald on 27.04.26.
//

import SwiftUI
import AVFoundation

// Zeigt das Live-Kamerabild in SwiftUI an --> Aus dem Tutorial: https://www.createwithswift.com/integrating-device-camera-in-swiftui-apps/?utm_source=chatgpt.com
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

// UIView mit AVCaptureVideoPreviewLayer als Layer [A Core Animation layer that displays video from a camera device]-->  https://developer.apple.com/documentation/avfoundation/setting-up-a-capture-session
final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
