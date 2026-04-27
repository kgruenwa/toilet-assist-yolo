//
//  Detection.swift
//  toilet-assist-yolo
//
//  Created by Katharina Grünwald on 27.04.26.
//

//Detection ist das Datenmodell für ein einzelnes erkanntes Objekt.
//Es speichert die erkannte Klasse, den Konfidenzwert und die Position des Objekts als Bounding Box.
//Die Struktur dient als zentrales Austauschformat zwischen dem Erkennungsmodell, dem ViewModel und der grafischen Darstellung.
//Ich brauche es um die sachen bei der Anwendung nur einmal erkennen zu müssen

//-->https://youtu.be/MXQnPt1BU1E Idee aus diesem Video

import Foundation
import CoreGraphics

// Eine einzelne erkannte Bounding Box.
// boundingBox ist im Vision-Format normalisiert:
// x/y/width/height liegen zwischen 0 und 1.
struct Detection: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect
}
