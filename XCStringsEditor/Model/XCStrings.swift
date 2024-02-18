//
//  XCStrings.swift
//  XCStringEditor
//
//  Created by JungHoon Noh on 1/24/24.
//

import Foundation

struct XCStrings: Codable {
    var version: String
    var sourceLanguage: Language
    var strings: [XCString]
    
    private enum CodingKeys: CodingKey {
        case sourceLanguage, version, strings
    }
        
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        version = try values.decode(String.self, forKey: .version)
        let sourceLanguageCode = try values.decode(String.self, forKey: .sourceLanguage)
        sourceLanguage = Language(code: sourceLanguageCode)!

        let stringDict = try values.decode([String: XCString].self, forKey: .strings)
        var strings = [XCString]()
        for (key, string) in stringDict {
            var string = string
            string.key = key
            strings.append(string)
        }
        self.strings = strings
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(version, forKey: .version)
        try container.encode(sourceLanguage.code, forKey: .sourceLanguage)
     
        var s = [String: XCString]()
        for string in strings {
            s[string.key!] = string
        }
        try container.encode(s, forKey: .strings)
    }
    
    func printStrings() {
        for string in strings {
            print(string.key ?? "-", string.comment ?? "-")

            for (key, l) in string.localizations {
                print(" ", key)

                if let stringUnit = l.stringUnit {
                    print("   ", stringUnit.value)

                } else if let pluralVariation = l.pluralVariation {
                    for (key, localization) in pluralVariation {
                        print("   plural", key, localization.stringUnit!.value)
                    }
                } else if let variation = l.deviceVariation {
                    for (key, localization) in variation {
                        print("   device", key)
                        if let stringUnit = localization.stringUnit {
                            print("     ", stringUnit.value)
                        } else if let pluralVariation = localization.pluralVariation {
                            for (key, localization) in pluralVariation {
                                print("       plural", key, localization.stringUnit!.value)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct XCString: Codable {
    enum ExtractionState: String {
        case none
        case stale
        case manual
    }
    enum VariationKind: CodingKey {
        case plural
        case device
    }

    enum DeviceType: String, Hashable {
        case iphone
        case ipod
        case ipad
        case applewatch
        case appletv
        case applevision
        case mac
        case other
        
        var sortNum: Int {
            switch self {
            case .iphone: return 0
            case .ipod: return 1
            case .ipad: return 2
            case .applewatch: return 3
            case .appletv: return 4
            case .applevision: return 5
            case .mac: return 6
            case .other: return 7
            }
        }
        
        var localizedName: String {
            switch self {
            case .iphone:
                return String(localized: "iPhone")
            case .ipod:
                return String(localized: "iPod")
            case .ipad:
                return String(localized: "iPad")
            case .applewatch:
                return String(localized: "Apple Watch")
            case .appletv:
                return String(localized: "Apple TV")
            case .applevision:
                return String(localized: "Apple Vision")
            case .mac:
                return String(localized: "Mac")
            case .other:
                return String(localized: "Other")
            }
        }
    }

    enum PluralType: String, Hashable {
        case zero
        case one
        case few
        case many
        case other
        
        var sortNum: Int {
            switch self {
            case .zero: return 0
            case .one: return 1
            case .few: return 2
            case .many: return 3
            case .other: return 4
            }
        }
        
        var localizedName: String {
            switch self {
            case .zero:
                return String(localized: "Zero")
            case .one:
                return String(localized: "One")
            case .few:
                return String(localized: "Few")
            case .many:
                return String(localized: "Many")
            case .other:
                return String(localized: "Other")
            }
        }
    }

    typealias PluralVariation = [PluralType: Localization]
    typealias DeviceVariation = [DeviceType: Localization]
    
    // Localization
    struct Localization: Codable {
        
        // StringUnit
        struct StringUnit: Codable {
            enum State: String {
                case new
                case translated
                case needsReview = "needs_review"
            }

            var state: State
            var value: String

            private enum CodingKeys: CodingKey {
                case state, value
            }

            init(state: State, value: String) {
                self.state = state
                self.value = value
            }

            init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                
                let stateValue = try values.decode(String.self, forKey: .state)
                state = State(rawValue: stateValue) ?? .new
                value = try values.decode(String.self, forKey: .value)
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)

                try container.encode(value, forKey: .value)
                try container.encode(state.rawValue, forKey: .state)
            }
            
            mutating func update(state: State, value: String) {
                
            }
        } // StringUnit
                
        var stringUnit: StringUnit?
        var pluralVariation: [PluralType: Localization]?
        var deviceVariation: [DeviceType: Localization]?
        
        init(stringUnit: StringUnit? = nil, pluralVariation: [PluralType: Localization]? = nil, deviceVariation: [DeviceType: Localization]? = nil) {
            self.stringUnit = stringUnit
            self.pluralVariation = pluralVariation
            self.deviceVariation = deviceVariation
        }
        
        private enum CodingKeys: CodingKey {
            case stringUnit, variations
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            
            stringUnit = try values.decodeIfPresent(StringUnit.self, forKey: .stringUnit)

            if stringUnit == nil {
                let variationContainer = try values.nestedContainer(keyedBy: VariationKind.self, forKey: .variations)
                
                if let pluralVariationDict = try variationContainer.decodeIfPresent([String: Localization].self, forKey: .plural) {
                    var pluralVariations = [PluralType: Localization]()
                    for (key, localization) in pluralVariationDict {
                        pluralVariations[PluralType(rawValue: key)!] = localization
                    }
                    self.pluralVariation = pluralVariations
                }
                
                if let deviceVariationDict = try variationContainer.decodeIfPresent([String: Localization].self, forKey: .device) {
                    var deviceVariations = [DeviceType: Localization]()
                    for (key, localization) in deviceVariationDict {
                        deviceVariations[DeviceType(rawValue: key)!] = localization
                    }
                    self.deviceVariation = deviceVariations
                }
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            if let stringUnit {
                try container.encode(stringUnit, forKey: .stringUnit)
                
            } else {
                if let pluralVariation {
                    var variations = [String: Localization]()
                    for (key, localization) in pluralVariation {
                        variations[key.rawValue] = localization
                    }
                    try container.encode(["plural": variations], forKey: .variations)

                } else if let deviceVariation {
                    var variations = [String: Localization]()
                    for (key, localization) in deviceVariation {
                        variations[key.rawValue] = localization
                    }
                    try container.encode(["device": variations], forKey: .variations)
                }
            }
        }
    } // Localization


    var comment: String?
    var key: String?
    var localizations: [Language: Localization]
    var extractionState: ExtractionState = .none
    
    private enum CodingKeys: CodingKey {
        case comment, key, localizations, extractionState
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if let comment {
            try container.encode(comment, forKey: .comment)
        }
        if extractionState != .none {
            try container.encode(extractionState.rawValue, forKey: .extractionState)
        }
        
        var l = [String: Localization]()
        for (key, localization) in localizations {
            l[key.rawValue] = localization
        }
        if l.isEmpty == false {
            try container.encode(l, forKey: .localizations)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        key = nil
        comment = try values.decodeIfPresent(String.self, forKey: .comment)
        if let stateValue = try values.decodeIfPresent(String.self, forKey: .extractionState), stateValue.isEmpty == false {
            extractionState = ExtractionState(rawValue: stateValue)!
        }
        
        if let localizationsDict = try values.decodeIfPresent([String: Localization].self, forKey: .localizations) {
            var localizations = [Language: Localization]()
            for (key, localization) in localizationsDict {
                localizations[Language(code: key)!] = localization
            }
            
            self.localizations = localizations
        } else {
            self.localizations = [:]
        }
    }
}
