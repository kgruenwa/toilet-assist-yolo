//
//  SingleModelDelector.swift
//  toilet-assist-yolo
//
//  Created by Katharina Grünwald on 27.04.26.
//

//SingleModelDetector führt ein einzelnes CoreML-Modell mit dem Vision-Framework auf einem Kamerabild aus.
//Die Ergebnisse werden als VNRecognizedObjectObservation ausgelesen, anschließend normalisiert und gefiltert.
//Es werden nur gewünschte Klassen übernommen, außerdem muss die Konfidenz über einem klassenspezifischen Schwellenwert liegen.
//Gültige Ergebnisse werden anschließend als Detection-Objekte mit Label, Confidence und Bounding Box zurückgegeben.

import Vision
import CoreML
import AVFoundation

final class SingleModelDetector {
    //VNCoreMLModel--> Innen: MLModell; Außen:--> Vision also Bildverarbeitung = Standartisierte Schnittstelle Für beides von Apple:https://developer.apple.com/documentation/Vision/VNCoreMLModel
    private let visionModel: VNCoreMLModel
    private let pickedNames: Set<String>

    init?(mlModel: MLModel, pickedNames: Set<String>) {
        do {
            self.visionModel = try VNCoreMLModel(for: mlModel)
            self.pickedNames = pickedNames
        } catch {
            print(" VNCoreMLModel Fehler: \(error)")
            return nil
        }
    }

    // Unterschiedliche Klassen brauchen unterschiedliche Confidence-Schwellen
    // Kleine Objekte wie Seifenspender brauchen niedrigere Werte; Da sie sonst gar nicht erkannt werden
    private func threshold(for label: String) -> Float {
        switch label {
        case "toilet":
            return 0.55
        case "sink":
            return 0.40
        case "soap_dispenser":
            return 0.35
        case "flush":
            return 0.30
        default:
            return 0.35
        }
    }

    // Führt eine Vision/CoreML-Erkennung auf einem Kameraframe aus;
    //VNCoreMLRequest= https://developer.apple.com/documentation/vision/vncoremlrequest
    //VNRecognizedObjectObservition= https://developer.apple.com/documentation/vision/vnrecognizedobjectobservation
    
    func detect(in pixelBuffer: CVPixelBuffer, completion: @escaping ([Detection]) -> Void) {
        let request = VNCoreMLRequest(model: visionModel) { request, error in
            if let error = error {
                print(" Vision error: \(error)")
                completion([])
                return
            }

            guard let results = request.results as? [VNRecognizedObjectObservation] else {
                print(" Keine VNRecognizedObjectObservation")
                completion([])
                return
            }

            let detections: [Detection] = results.compactMap { obs in
                guard let top = obs.labels.first else { return nil }

                let canonical = LabelNormalizer.canonical(top.identifier)

                // Nur Klassen behalten, die dieses Modell liefern soll
                guard self.pickedNames.contains(canonical) else {
                    return nil
                }

                // Confidence prüfen.
                let requiredConfidence = self.threshold(for: canonical)
                guard top.confidence >= requiredConfidence else {
                    return nil
                }

                // Schutz gegen kleine Fehlklassifikationen bei Toilette.
                // Kann später entfernt werden, wenn dein eigenes Modell besser trainiert ist.
                let boxArea = obs.boundingBox.width * obs.boundingBox.height

                switch canonical {
                case "toilet":
                    guard boxArea > 0.04 else { return nil }
                case "sink":
                    guard boxArea > 0.025 else { return nil }
                case "soap_dispenser":
                    guard boxArea > 0.008 else { return nil }
                case "toilet_door_open", "toilet_door_closed":
                    guard boxArea > 0.03 else { return nil }
                case "flush":
                    guard boxArea > 0.004 else { return nil }
                default:
                    break
                }

                return Detection(
                    label: canonical,
                    confidence: top.confidence,
                    boundingBox: obs.boundingBox
                )
            }

            let filteredDetections = DetectionMath.nms(detections, iouThreshold: 0.45)
            completion(filteredDetections)
        }

        // scaleFill passt zum PreviewLayer resizeAspectFill.
        // VNImageRewuestHandler= https://developer.apple.com/documentation/vision/vnimagerequesthandler
        request.imageCropAndScaleOption = .scaleFill

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            print(" Request fehlgeschlagen: \(error)")
            completion([])
        }
    }
}
