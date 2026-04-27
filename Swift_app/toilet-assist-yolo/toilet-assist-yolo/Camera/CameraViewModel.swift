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

// Tutorial für AVCaptureVideoDataOutputSampleBUfferDelegate-->
// https://developer.apple.com/documentation/vision/recognizing-objects-in-live-capture und
// https://neuralception.com/detection-app-tutorial-detector/

//weiteres Wichtiges Tutorial: https://www.juliushietala.com/blog/yolov5-coreml

final class CameraViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var detections: [Detection] = []
    @Published var navigationTarget: NavigationTarget = .automatic
    @Published var spokenHint: String = ""

    let session = AVCaptureSession()
    
    private let speechFeedback = SpeechFeedbackManager()
    private let audioCue = AudioCueManager()
    private let hapticFeedback = HapticFeedbackManager()

    private var lastDetectedLabel: String?
    private var wasTargetVisible: Bool = false

    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera.queue")
    private var isProcessing = false

    private var baseDetector: SingleModelDetector?
    private var customDetector: SingleModelDetector?

    private let iouMerge: CGFloat = 0.5

    // Basis-YOLO liefert aktuell Toilette/Waschbecken.
    private let useFromBase: Set<String> = ["sink", "toilet"]

    // Custom-Modell liefert deine selbst trainierten Klassen.
    private let useFromCustom: Set<String> = [
        "soap_dispenser",
        "toilet_door_open",
        "toilet_door_closed"
    ]


    override init() {
        super.init()
        setupModels()
        setupCamera()
    }

    private func setupModels() {
        do {
            let config = MLModelConfiguration()

            let baseMLModel = try yolo11s(configuration: config).model
            let customMLModel = try best(configuration: config).model

            baseDetector = SingleModelDetector(
                mlModel: baseMLModel,
                pickedNames: useFromBase
            )

            customDetector = SingleModelDetector(
                mlModel: customMLModel,
                pickedNames: useFromCustom
            )

            print("Base-Modell geladen: \(useFromBase)")
            print("Custom-Modell geladen: \(useFromCustom)")
        } catch {
            print("Modelle konnten nicht geladen werden: \(error)")
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
        case "toilet_door_open":
            return "Offene Tür gefunden"
        case "toilet_door_closed":
            return "Tür gefunden"
        default:
            return "Ziel gefunden"
        }
    }

    private func directionValue(for detection: Detection) -> Float {
        let x = Float(detection.boundingBox.midX)

        // Vision-Koordinate:
        // links ungefähr 0, Mitte 0.5, rechts 1.
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

        // Grobe Nähe über Boxgröße.
        // 0 = weit weg, 1 = sehr nah.
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

    private func handleFeedback(for detections: [Detection]) {
        guard let target = detections.first else {
            audioCue.stop()

            if wasTargetVisible {
                speechFeedback.speakStatus("Ziel verloren")
                hapticFeedback.targetLost()
            }

            wasTargetVisible = false
            lastDetectedLabel = nil
            return
        }

        let direction = directionValue(for: target)
        let closeness = closenessValue(for: target)

        // Kontinuierliche Navigation über Beeps.
        audioCue.update(direction: direction, closeness: closeness)

        // Sprache nur bei neuem Zieltyp.
        if lastDetectedLabel != target.label {
            speechFeedback.speakStatus(statusText(for: target))
            lastDetectedLabel = target.label
        }

        // Haptik nur bei sehr nah.
        if closeness > 0.85 {
            hapticFeedback.targetVeryNear()
        }

        wasTargetVisible = true
    }
    
    // Tutorial  for the AVCaptureDevice --> https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app?utm_source=chatgpt.com
    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
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

            // Alte Frames werden verworfen, damit die App live bleibt.
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

    // Wird für jeden Kameraframe aufgerufen.
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard !isProcessing else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let baseDetector, let customDetector else { return }

        isProcessing = true

        let group = DispatchGroup()
        var baseDetections: [Detection] = []
        var customDetections: [Detection] = []

        group.enter()
        baseDetector.detect(in: pixelBuffer) { detections in
            baseDetections = detections
            group.leave()
        }

        group.enter()
        customDetector.detect(in: pixelBuffer) { detections in
            customDetections = detections
            group.leave()
        }

        group.notify(queue: queue) {
            let merged = baseDetections + customDetections
            let afterNMS = DetectionMath.nms(merged, iouThreshold: self.iouMerge)
            let finalDetections = self.navigationSelection(afterNMS)

            let hint = finalDetections.first.map {
                self.speechText(for: $0)
            } ?? "Kein Ziel sichtbar."

            DispatchQueue.main.async {
                self.detections = finalDetections
                self.spokenHint = hint
                self.handleFeedback(for: finalDetections)
            }

            self.isProcessing = false
        }
    }

    // Wählt genau ein Navigationsziel aus.
    // Im Automatikmodus gilt: Toilette > Waschbecken > Seifenspender > Tür.
    private func navigationSelection(_ detections: [Detection]) -> [Detection] {
        let candidates: [Detection]

        switch navigationTarget {
        case .automatic:
            let toilets = detections.filter { $0.label == "toilet" }
            let sinks = detections.filter { $0.label == "sink" }
            let soaps = detections.filter { $0.label == "soap_dispenser" }
            let doors = detections.filter {
                $0.label == "toilet_door_open" || $0.label == "toilet_door_closed"
            }

            candidates =
                bestDetection(from: toilets).map { [$0] } ??
                bestDetection(from: sinks).map { [$0] } ??
                bestDetection(from: soaps).map { [$0] } ??
                bestDetection(from: doors).map { [$0] } ??
                []

        default:
            candidates = detections.filter {
                navigationTarget.labels.contains($0.label)
            }
        }

        guard let best = bestDetection(from: candidates) else {
            return []
        }

        return [best]
    }

    // Wählt die plausibelste Detection.
    // Confidence zählt stark, Boxgröße etwas weniger.
    private func bestDetection(from detections: [Detection]) -> Detection? {
        detections.max { a, b in
            let areaA = a.boundingBox.width * a.boundingBox.height
            let areaB = b.boundingBox.width * b.boundingBox.height

            let scoreA = a.confidence + Float(areaA) * 0.25
            let scoreB = b.confidence + Float(areaB) * 0.25

            return scoreA < scoreB
        }
    }

    // Teilt das Bild horizontal ein.
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

    // Grobe Distanzschätzung über die Boxgröße.
    // Ohne LiDAR/Tiefenkamera ist das nur eine Annäherung.
    private func distanceText(for detection: Detection) -> String {
        let area = detection.boundingBox.width * detection.boundingBox.height

        if area > 0.35 {
            return "sehr nah"
        } else if area > 0.18 {
            return "nah"
        } else if area > 0.08 {
            return "einige Schritte entfernt"
        } else {
            return "weiter entfernt"
        }
    }

    // Baut den kurzen Navigationssatz.
    private func speechText(for detection: Detection) -> String {
        let direction = directionText(for: detection)

        switch detection.label {
        case "toilet":
            return "Toilette \(direction)."
        case "sink":
            return "Waschbecken \(direction)."
        case "soap_dispenser":
            return "Seife \(direction)."
        case "toilet_door_open":
            return "Tür \(direction)."
        case "toilet_door_closed":
            return "Tür \(direction)."
        default:
            return "\(detection.label) \(direction)."
        }
    }
}
