//Die Datei baut den Bildschirm der App.
//Im Hintergrund sieht man die Kamera.
//Darüber werden erkannte Objekte markiert.
//Oben kann man ein Ziel auswählen.
//In der Mitte erscheint ein Hinweis, wohin man gehen soll.
//Unten sieht man zu Testzwecken, was das Modell gerade erkannt hat


import SwiftUI


struct ContentView: View {
    @StateObject private var cameraVM = CameraViewModel()

    var body: some View {
        //ZStack wird verwendet, um Kamera, Erkennungsoverlay und UI-Elemente in mehreren Ebenen übereinander darzustellen.--> https://neuralception.com/detection-app-tutorial-detector/
        ZStack {
            CameraPreview(session: cameraVM.session)
                .ignoresSafeArea()

            DetectionOverlay(detections: cameraVM.detections)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // Zielauswahl für die Navigation. Also die Interaktive navigation was man sucht
                Picker("Ziel", selection: $cameraVM.navigationTarget) {
                    ForEach(NavigationTarget.allCases) { target in
                        Text(target.rawValue).tag(target)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)

                // Aktueller Navigationshinweis.
                Text(cameraVM.spokenHint)
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())

                Spacer()

                // Debug-Anzeige der aktuell ausgewählten Detection.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(cameraVM.detections) { det in
                            Text("\(det.label) \(String(format: "%.2f", det.confidence))")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            cameraVM.startSession()
        }
        .onDisappear {
            cameraVM.stopSession()
        }
    }
}
