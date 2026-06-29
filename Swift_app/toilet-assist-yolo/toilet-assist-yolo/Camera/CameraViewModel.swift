//
//  CameraViewModel.swift
//  toilet-assist-yolo
//
//  Created by Katharina Grünwald on 27.04.26.
//

import SwiftUI
import AVFoundation
import CoreML
import Combine

final class CameraViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    @Published var detections: [Detection] = []
    @Published var spokenHint: String = ""
    @Published var flowManager = AssistiveFlowManager()

    let session = AVCaptureSession()

    private let speechFeedback = SpeechFeedbackManager()
    private let audioCue = AudioCueManager()

    @Published var isAudioCueEnabled: Bool = UserDefaults.standard.object(forKey: "isAudioCueEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isAudioCueEnabled, forKey: "isAudioCueEnabled")

            if !isAudioCueEnabled {
                audioCue.stop()
            }
        }
    }

    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera.queue")

    private var detector: SingleModelDetector?
    private var isProcessing = false

    private var lastDetectedLabel: String?
    private var wasTargetVisible: Bool = false

    private var stableTargetLabel: String?
    private var stableFrameCount: Int = 0
    private var missingFrameCount: Int = 0

    private let requiredStableFrames = 2
    private let allowedMissingFrames = 3

    // Tür-Erkennung ist hier bewusst entfernt.
    private let pickedNames: Set<String> = [
        "sink",
        "soap_dispenser",
        "toilet",
        "flush"
    ]

    override init() {
        super.init()
        setupModels()
        setupCamera()
    }

    private func setupModels() {
        do {
            let config = MLModelConfiguration()

            // Falls dein CoreML-Modell in Xcode anders heißt,
            // musst du "best" hier anpassen.
            let customMLModel = try bestnewversion(configuration: config).model

            detector = SingleModelDetector(
                mlModel: customMLModel,
                pickedNames: pickedNames
            )

            print("Custom-Modell geladen: \(pickedNames)")
        } catch {
            print("Custom-Modell konnte nicht geladen werden: \(error)")
        }
    }

    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            print("Keine Kamera gefunden")
            session.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)

            guard session.canAddInput(input) else {
                print("Kamera-Input konnte nicht hinzugefügt werden")
                session.commitConfiguration()
                return
            }

            session.addInput(input)

            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]

            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: queue)

            guard session.canAddOutput(videoOutput) else {
                print("Video-Output konnte nicht hinzugefügt werden")
                session.commitConfiguration()
                return
            }

            session.addOutput(videoOutput)

            if let connection = videoOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }

            session.commitConfiguration()
        } catch {
            print("Kamera-Fehler: \(error)")
            session.commitConfiguration()
        }
    }

    func startSession() {
        guard !session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }

    // MARK: - Bedienung

    func speakIntro() {
        let intro = """
        Willkommen bei der Toiletten Assistenz.
            Halten Sie das iPhone aufrecht vor sich.
            Die App sucht nacheinander Toilette, Spülung, Waschbecken und Seifenspender.
            Doppeltippen Sie irgendwo auf den Bildschirm, um zum nächsten Schritt zu wechseln.
            Dreifachtippen Sie irgendwo auf den Bildschirm, um zum vorherigen Schritt zurückzugehen.
            Drücken und halten Sie den Bildschirm, um die aktuelle Anweisung erneut zu hören.
        \(flowManager.currentInstruction)
        """

        speechFeedback.speakStatus(intro)
    }

    func repeatCurrentInstruction() {
        speechFeedback.speakStatus(flowManager.currentInstruction)
    }

    func goToNextStep() {
        flowManager.nextStep()

        resetDetectionState()

        speechFeedback.speakStatus(flowManager.currentInstruction)
    }

    func goToPreviousStep() {
        flowManager.previousStep()

        resetDetectionState()

        speechFeedback.speakStatus(flowManager.currentInstruction)
    }

    private func resetDetectionState() {
        lastDetectedLabel = nil
        wasTargetVisible = false
        stableTargetLabel = nil
        stableFrameCount = 0
        missingFrameCount = 0
        audioCue.stop()
    }

    // MARK: - Kamera-Frames

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard !isProcessing else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let detector else { return }

        isProcessing = true

        detector.detect(in: pixelBuffer) { detections in
            let finalDetections = self.navigationSelection(detections)

            let hint = finalDetections.first.map {
                self.speechText(for: $0)
            } ?? self.flowManager.currentInstruction

            DispatchQueue.main.async {
                self.detections = finalDetections
                self.spokenHint = hint
                self.handleFeedback(for: finalDetections, allDetections: detections)
            }

            self.isProcessing = false
        }
    }

    // MARK: - Auswahl des aktuellen Zielobjekts

    private func navigationSelection(_ detections: [Detection]) -> [Detection] {
        let candidates = detections.filter {
            flowManager.currentStep.targetLabels.contains($0.label)
        }

        guard let best = bestDetection(from: candidates) else {
            return []
        }

        return [best]
    }

    private func bestDetection(from detections: [Detection]) -> Detection? {
        detections.max { a, b in
            let areaA = a.boundingBox.width * a.boundingBox.height
            let areaB = b.boundingBox.width * b.boundingBox.height

            let scoreA = a.confidence + Float(areaA) * 0.25
            let scoreB = b.confidence + Float(areaB) * 0.25

            return scoreA < scoreB
        }
    }

    // MARK: - Feedback-Logik

    private func handleFeedback(for detections: [Detection], allDetections: [Detection]) {
        guard let target = detections.first else {
            audioCue.stop()

            missingFrameCount += 1

            if missingFrameCount >= allowedMissingFrames {
                wasTargetVisible = false
                lastDetectedLabel = nil
                stableTargetLabel = nil
                stableFrameCount = 0
            }

            return
        }

        missingFrameCount = 0

        if stableTargetLabel == target.label {
            stableFrameCount += 1
        } else {
            stableTargetLabel = target.label
            stableFrameCount = 1
        }

        guard stableFrameCount >= requiredStableFrames else {
            return
        }

        let direction = directionValue(for: target)
        let closeness = closenessValue(for: target)

        if isAudioCueEnabled {
            audioCue.update(direction: direction, closeness: closeness)
        } else {
            audioCue.stop()
        }

        if lastDetectedLabel != target.label {
            let message = feedbackMessage(for: target, allDetections: allDetections)

            speechFeedback.speakStatus(message)
            lastDetectedLabel = target.label
        }

        wasTargetVisible = true
    }

    private func directionValue(for detection: Detection) -> Float {
        let x = Float(detection.boundingBox.midX)

        if x < 0.20 {
            return -1.0
        } else if x < 0.40 {
            return -0.5
        } else if x < 0.60 {
            return 0.0
        } else if x < 0.80 {
            return 0.5
        } else {
            return 1.0
        }
    }

    private func closenessValue(for detection: Detection) -> Float {
        let area = Float(detection.boundingBox.width * detection.boundingBox.height)

        if area > 0.35 {
            return 1.0
        } else if area > 0.18 {
            return 0.70
        } else if area > 0.08 {
            return 0.40
        } else {
            return 0.15
        }
    }

    // MARK: - Sprachtexte

    private func directionText(for detection: Detection) -> String {
        let x = detection.boundingBox.midX

        if x < 0.20 {
            return "stark links"
        } else if x < 0.40 {
            return "leicht links"
        } else if x < 0.60 {
            return "geradeaus"
        } else if x < 0.80 {
            return "leicht rechts"
        } else {
            return "stark rechts"
        }
    }

    private func speechText(for detection: Detection) -> String {
        let direction = directionText(for: detection)

        switch detection.label {
        case "toilet":
            return "Toilette \(direction)."
        case "sink":
            return "Waschbecken \(direction)."
        case "soap_dispenser":
            return "Seifenspender \(direction)."
        case "flush":
            return "Spülung \(direction)."
        default:
            return "\(detection.label) \(direction)."
        }
    }

    private func statusText(for detection: Detection) -> String {
        switch detection.label {
        case "toilet":
            return "Toilette gefunden"
        case "sink":
            return "Waschbecken gefunden"
        case "soap_dispenser":
            return "Seifenspender gefunden"
        case "flush":
            return "Spülung gefunden"
        default:
            return "Ziel gefunden"
        }
    }
    
    private func feedbackMessage(for target: Detection, allDetections: [Detection]) -> String {
        if target.label == "flush" {
            return flushFeedbackMessage(for: target, allDetections: allDetections)
        }

        let directionText = directionText(for: target)
        return "\(flowManager.currentStep.successMessage) \(directionText)."
    }

    private func flushFeedbackMessage(for flush: Detection, allDetections: [Detection]) -> String {
        guard let toilet = allDetections.first(where: { $0.label == "toilet" }) else {
            let directionText = directionText(for: flush)
            return "Spülung erkannt \(directionText)."
        }

        let flushCenterX = flush.boundingBox.midX
        let flushCenterY = flush.boundingBox.midY

        let toiletCenterX = toilet.boundingBox.midX
        let toiletCenterY = toilet.boundingBox.midY

        let horizontalDistance = abs(flushCenterX - toiletCenterX)
        let maxHorizontalDistance = toilet.boundingBox.width * 0.7

        if flushCenterY < toiletCenterY && horizontalDistance < maxHorizontalDistance {
            return "Die Spülung ist direkt über der Toilette."
        } else if flushCenterX < toiletCenterX {
            return "Die Spülung ist links von der Toilette."
        } else if flushCenterX > toiletCenterX {
            return "Die Spülung ist rechts von der Toilette."
        } else {
            return "Spülung erkannt."
        }
    }
}
