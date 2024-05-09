//
//  TranslationStatus.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 5/8/24.
//

import Foundation
import SwiftUI

enum TranslationStatus {
    /// Translation is missing
    case missingTranslation
    /// Reverse translation is missing
    case missingReverse
    /// Reverse translation and source are very different
    case different
    /// Reverse translation is similar to the source
    case similar
    /// Reverse translation is the same as the source
    case exact
}
