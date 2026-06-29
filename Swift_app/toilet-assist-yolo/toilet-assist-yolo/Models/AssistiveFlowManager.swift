import Foundation
import Combine
import CoreGraphics

final class AssistiveFlowManager: ObservableObject {
    @Published private(set) var currentStep: AssistiveStep = .locateToilet

    var currentTitle: String {
        currentStep.title
    }

    var currentInstruction: String {
        currentStep.instruction
    }

    func instruction(for detections: [Detection]) -> String {
        switch currentStep {
        case .findFlush:
            return flushInstruction(from: detections)

        default:
            return currentStep.instruction
        }
    }

    var currentStepNumber: Int {
        guard let index = AssistiveStep.allCases.firstIndex(of: currentStep) else {
            return 1
        }

        return index + 1
    }

    var totalSteps: Int {
        AssistiveStep.allCases.count
    }

    func nextStep() {
        let allSteps = AssistiveStep.allCases

        guard let currentIndex = allSteps.firstIndex(of: currentStep) else {
            currentStep = allSteps.first ?? .locateToilet
            return
        }

        let nextIndex = currentIndex + 1

        if nextIndex < allSteps.count {
            currentStep = allSteps[nextIndex]
        } else {
            currentStep = allSteps[0]
        }
    }

    func previousStep() {
        let steps = AssistiveStep.allCases

        guard let currentIndex = steps.firstIndex(of: currentStep),
              currentIndex > 0 else {
            return
        }

        currentStep = steps[currentIndex - 1]
    }

    private func flushInstruction(from detections: [Detection]) -> String {
        guard let flush = detections.first(where: { $0.label == "flush" }) else {
            return "Suchen Sie die Spülung."
        }

        guard let toilet = detections.first(where: { $0.label == "toilet" }) else {
            return "Spülung erkannt."
        }

        let flushCenterX = flush.boundingBox.midX
        let flushCenterY = flush.boundingBox.midY

        let toiletCenterX = toilet.boundingBox.midX
        let toiletCenterY = toilet.boundingBox.midY

        let horizontalDistance = abs(flushCenterX - toiletCenterX)

        if flushCenterY < toiletCenterY && horizontalDistance < toilet.boundingBox.width * 0.7 {
            return "Die Spülung ist direkt über der Toilette."
        } else if flushCenterX < toiletCenterX {
            return "Die Spülung ist links von der Toilette."
        } else if flushCenterX > toiletCenterX {
            return "Die Spülung ist rechts von der Toilette."
        } else {
            return "Spülung erkannt."
        }
    }

    func reset() {
        currentStep = .locateToilet
    }
}
