//
//  LabelNormalizer.swift
//  toilet-assist-yolo
//
//  Created by Katharina Grünwald on 27.04.26.
//

import Foundation

// Vereinheitlicht verschiedene Klassennamen


enum LabelNormalizer {
    static let map: [String: String] = [
        "washbasin": "sink",
        "basin": "sink",
        "wc": "toilet",
        "toilet_bowl": "toilet",
        "soap-dispenser": "soap_dispenser",
        "soap": "soap_dispenser",
    ]

    static func canonical(_ name: String) -> String {
        map[name] ?? name
    }
}
