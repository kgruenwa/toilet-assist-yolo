//
//  NavigationTarget.swift
//  toilet-assist-yolo
//
//  Created by Katharina Grünwald on 27.04.26.
//

import Foundation

// Ziel, das die blinde Person auswählen kann.
// Danach sucht die App gezielt nur nach diesem Objekt.
enum NavigationTarget: String, CaseIterable, Identifiable {
    case automatic = "Automatisch"
    case toilet = "Toilette"
    case sink = "Waschbecken"
    case soap = "Seifenspender"
    
    var id: String { rawValue }
    
    // Labels, die zu diesem Navigationsziel gehören.
    var labels: Set<String> {
        switch self {
        case .automatic:
            return ["toilet", "sink", "soap_dispenser"]
        case .toilet:
            return ["toilet"]
        case .sink:
            return ["sink"]
        case .soap:
            return ["soap_dispenser"]
        }
    }
}
