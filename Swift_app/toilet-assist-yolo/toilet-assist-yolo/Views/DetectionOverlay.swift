//
//  DetectionOverlay.swift
//  toilet-assist-yolo
//
//  Created by Katharina Grünwald on 27.04.26.
//

//DetectionOverlay zeichnet die vom Modell erkannten Objekte als Bounding Boxes über das Kamerabild.
//Für jedes erkannte Objekt wird ein Rechteck mit Klassenname und Konfidenzwert angezeigt.
//Da Vision und SwiftUI unterschiedliche Koordinatensysteme verwenden, werden die Modellkoordinaten vor dem Zeichnen zunächst auf das Bildschirmkoordinatensystem umgerechnet.

//Bedient habe ich mich hier an den Tutorials die in anderen Datein Genannt wurden!!

import SwiftUI

// Zeichnet Bounding Boxes über das Kamerabild.
struct DetectionOverlay: View {
    let detections: [Detection]

    var body: some View {
        //liefert die tatsächliche Größe der Anzeigefläche, damit die Modellkoordinaten korrekt auf den Bildschirm skaliert werden können
        GeometryReader { geo in
            ForEach(detections) { det in
                //Die normalisierten Modellkoordinaten werden in reale Bildschirmkoordinaten umgerechnet.
                let rect = convertRect(det.boundingBox, in: geo.size)

                //Anzeige Rechteck und Label 
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .stroke(.green, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)

                    Text("\(det.label) \(String(format: "%.2f", det.confidence))")
                        .font(.caption2)
                        .padding(4)
                        .background(.green)
                        .foregroundColor(.black)
                        .position(
                            x: min(rect.minX + 80, geo.size.width - 80),
                            y: max(rect.minY + 10, 12)
                        )
                }
            }
        }
    }

    // Vision nutzt ein anderes Koordinatensystem als SwiftUI.
    // Deshalb wird y hier umgerechnet.
    private func convertRect(_ boundingBox: CGRect, in size: CGSize) -> CGRect {
        let width = boundingBox.width * size.width
        let height = boundingBox.height * size.height
        let x = boundingBox.minX * size.width
        let y = (1 - boundingBox.minY - boundingBox.height) * size.height

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
