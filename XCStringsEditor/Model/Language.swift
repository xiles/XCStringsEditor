//
//  Language.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 2/8/24.
//

import Foundation

enum Language: String, Hashable, Identifiable, CustomStringConvertible {
    case arabic = "ar"
    case catalan = "ca"
    case chineseHongKong = "zh-HK"
    case chinese = "zh-Hans" // zh-CN
    case chineseTraditional = "zh-Hant" // zh-TW
    case croatian = "hr"
    case czech = "cs"
    case danish = "da"
    case dutch = "nl"
    case english = "en"
    case englishAustralia = "en-AU"
    case englishIndia = "en-IN"
    case englishGB = "en-GB"
    case finnish = "fi"
    case french = "fr"
    case frenchCanada = "fr-CA"
    case german = "de"
    case greek = "el"
    case hebrew = "he"
    case hindi = "hi"
    case hungarian = "hu"
    case indonesian = "id"
    case italian = "it"
    case japanese = "ja"
    case korean = "ko" // ko
    case malay = "ms"
    case norwegianBokmal = "nb"
    case polish = "pl"
    case portugueseBrazil = "pt-BR"
    case portugese = "pt-PT"
    case romanian = "ro"
    case russian = "ru"
    case slovak = "sk"
    case spanish = "es"
    case spanishLatinAmerica = "es-419"
    case swedish = "sv"
    case thai = "th"
    case turkish = "tr"
    case ukrainian = "uk"
    case vietnamese = "vi"
    
    var id: Self { self }

    init?(code: String) {
        self.init(rawValue: code)
    }

    var code: String {
        return self.rawValue
    }
    
    var localizedName: String {
        switch self {
        case .english: return String(localized: "English")
        case .korean: return String(localized: "Korean")
        case .german: return String(localized: "German")
        case .spanish: return String(localized: "Spanish")
        case .french: return String(localized: "French")
        case .japanese: return String(localized: "Japanese")
        case .chinese: return String(localized: "Chinese(Simplified)")
        case .chineseTraditional: return String(localized: "Chinese(Traditional)")
        case .russian: return String(localized: "Russian")
        case .arabic: return String(localized: "Arabic")
        case .catalan:
            return String(localized: "Catalan")
        case .chineseHongKong:
            return String(localized: "Chinese (Hong Kong)")
        case .croatian:
            return String(localized: "Croatian")
        case .czech:
            return String(localized: "Czech")
        case .danish:
            return String(localized: "Danish")
        case .dutch:
            return String(localized: "Dutch")
        case .englishAustralia:
            return String(localized: "English (Australia)")
        case .englishIndia:
            return String(localized: "English (India)")
        case .englishGB:
            return String(localized: "English (United Kingdom")
        case .finnish:
            return String(localized: "Finnish")
        case .frenchCanada:
            return String(localized: "French (Canada)")
        case .greek:
            return String(localized: "Greek")
        case .hebrew:
            return String(localized: "Hebrew")
        case .hindi:
            return String(localized: "Hindi")
        case .hungarian:
            return String(localized: "Hungarian")
        case .indonesian:
            return String(localized: "Indonesian")
        case .italian:
            return String(localized: "Italian")
        case .malay:
            return String(localized: "Malay")
        case .norwegianBokmal:
            return String(localized: "Norwegian Bokmål")
        case .polish:
            return String(localized: "Polish")
        case .portugueseBrazil:
            return String(localized: "Portugese (Brazil)")
        case .portugese:
            return String(localized: "Portugese (Portugal)")
        case .romanian:
            return String(localized: "Romanian")
        case .slovak:
            return String(localized: "Slovak")
        case .spanishLatinAmerica:
            return String(localized: "Spanish (Latin America)")
        case .swedish:
            return String(localized: "Swedish")
        case .thai:
            return String(localized: "Thai")
        case .turkish:
            return String(localized: "Turkish")
        case .ukrainian:
            return String(localized: "Ukrainian")
        case .vietnamese:
            return String(localized: "Vietnamese")
        }
    }
    
    var description: String {
        return code
    }

}
