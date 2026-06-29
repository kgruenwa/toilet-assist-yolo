import Foundation

enum AssistiveStep: Int, CaseIterable, Identifiable {
    case locateToilet
    case findFlush
    case findSink
    case findSoapDispenser

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
 
        case .locateToilet:
            return "Toilette lokalisieren"
        case .findFlush:
            return "Spülung finden"
        case .findSink:
            return "Waschbecken finden"
        case .findSoapDispenser:
            return "Seifenspender finden"
        }
    }

    var instruction: String {
        switch self {
        case .locateToilet:
            return "Schritt 1 von 4. Suchen Sie die Toilette."
        case .findFlush:
            return "Schritt 2 von 4. Suchen Sie die Spülung."
        case .findSink:
            return "Schritt 3 von 4. Suchen Sie das Waschbecken."
        case .findSoapDispenser:
            return "Schritt 4 von 4. Suchen Sie den Seifenspender."
        }
    }
    var targetLabels: Set<String> {
        switch self {
        case .locateToilet:
            return ["toilet"]
        case .findFlush:
            return ["flush"]
        case .findSink:
            return ["sink"]
        case .findSoapDispenser:
            return ["soap_dispenser"]
        }
    }

    var successMessage: String {
        switch self {
        case .locateToilet:
            return "Toilette erkannt"
        case .findFlush:
            return "Spülung erkannt"
        case .findSink:
            return "Waschbecken erkannt"
        case .findSoapDispenser:
            return "Seifenspender erkannt"
        }
    }
}
