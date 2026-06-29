import SwiftUI

struct ContentView: View {
    @StateObject private var cameraVM = CameraViewModel()
    @State private var showHelperPanel = false

    private let showDebugOverlay = true

    var body: some View {
        ZStack {
            CameraPreview(session: cameraVM.session)
                .ignoresSafeArea()

            if showDebugOverlay {
                DetectionOverlay(detections: cameraVM.detections)
                    .ignoresSafeArea()
                    .opacity(0.35)
                    .accessibilityHidden(true)
            }

            Color.clear
                .contentShape(Rectangle())
                .accessibilityElement()
                .accessibilityLabel("Toiletten Assistenz")
                .accessibilityHint("Doppeltippen für den nächsten Schritt. Lange drücken, um die aktuelle Anweisung erneut zu hören.")
                .accessibilityAction(named: "Nächster Schritt") {
                    cameraVM.goToNextStep()
                }
                .accessibilityAction(named: "Vorheriger Schritt") {
                    cameraVM.goToPreviousStep()
                }
                .accessibilityAction(named: "Anweisung wiederholen") {
                    cameraVM.repeatCurrentInstruction()
                }

            // Bedienhilfe für sehende Begleitpersonen
            VStack {
                HStack {
                    Spacer()

                    Button {
                        showHelperPanel.toggle()
                    } label: {
                        Text("Hilfe")
                            .font(.headline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("Bedienhilfe öffnen")
                    .accessibilityHint("Öffnet Hinweise und Steuerung für sehende Begleitpersonen.")
                }
                .padding()

                Spacer()
            }

            if showHelperPanel {
                helperPanel
            }

            if showDebugOverlay {
                debugBar
                    .accessibilityHidden(true)
            }
        }
        .onTapGesture(count: 3) {
            cameraVM.goToPreviousStep()
        }
        .onTapGesture(count: 2) {
            cameraVM.goToNextStep()
        }
        .onLongPressGesture {
            cameraVM.repeatCurrentInstruction()
        }
        .onAppear {
            cameraVM.startSession()
            cameraVM.speakIntro()
        }
        .onDisappear {
            cameraVM.stopSession()
        }
    }

    private var helperPanel: some View {
        VStack(spacing: 14) {
            Text("Bedienhilfe")
                .font(.title2)
                .bold()

            VStack(alignment: .leading, spacing: 8) {
                Text("Aktueller Schritt:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Schritt \(cameraVM.flowManager.currentStepNumber) von \(cameraVM.flowManager.totalSteps)")
                    .font(.headline)

                Text(cameraVM.flowManager.currentInstruction)
                    .font(.body)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Bedienung für blinde Nutzer*innen:")
                    .font(.headline)

                Text("• Doppeltippen irgendwo auf den Bildschirm: nächster Schritt")
                Text("• Lange drücken: aktuelle Anweisung wiederholen")
                Text("• Die App sucht immer nur das Ziel des aktuellen Schritts")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Toggle("Zusätzliche Tonsignale", isOn: $cameraVM.isAudioCueEnabled)
                .font(.headline)
                .accessibilityLabel("Zusätzliche Tonsignale")
                .accessibilityHint("Schaltet nur die zusätzlichen Richtungstöne ein oder aus. Die Sprachausgabe bleibt aktiv.")

            Text("Wenn diese Option ausgeschaltet ist, spricht die App weiterhin Hinweise wie Toilette links oder Waschbecken rechts. Nur der zusätzliche Ton wird deaktiviert.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack(spacing: 10) {
                Button {
                    cameraVM.goToPreviousStep()
                } label: {
                    Text("Zurück")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    cameraVM.repeatCurrentInstruction()
                } label: {
                    Text("Wiederholen")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    cameraVM.goToNextStep()
                } label: {
                    Text("Weiter")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            if showDebugOverlay && !cameraVM.detections.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Aktuelle Erkennung:")
                        .font(.headline)

                    ForEach(cameraVM.detections.prefix(4)) { det in
                        Text("\(det.label): \(String(format: "%.2f", det.confidence))")
                            .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                showHelperPanel = false
            } label: {
                Text("Schließen")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.black.opacity(0.75))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding()
    }

    private var debugBar: some View {
        VStack {
            Spacer()

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
}
