//
//  DetectionMath.swift
//  toilet-assist-yolo
//
//  Created by Katharina Grünwald on 27.04.26.
//

import CoreGraphics

enum DetectionMath {
    // Berechnet die Überlappung zweier Boxen
    // Wird für Non-Maximum-Suppression genutzt --> https://github.com/hollance/CoreMLHelpers/blob/master/CoreMLHelpers/NonMaxSuppression.swift?
    static func iou(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let inter = a.intersection(b)
        if inter.isNull { return 0 }

        let interArea = inter.width * inter.height
        let unionArea = a.width * a.height + b.width * b.height - interArea

        guard unionArea > 0 else { return 0 }
        return interArea / unionArea
    }

    // Entfernt doppelte Boxen; Wenn zwei Boxen stark überlappen, bleibt nur die mit höherer Confidence
    
    static func nms(_ detections: [Detection], iouThreshold: CGFloat) -> [Detection] {
        let sorted = detections.sorted { $0.confidence > $1.confidence }
        var kept: [Detection] = []

        for det in sorted {
            let overlaps = kept.contains { existing in
                iou(det.boundingBox, existing.boundingBox) >= iouThreshold
            }

            if !overlaps {
                kept.append(det)
            }
        }

        return kept
    }
}
