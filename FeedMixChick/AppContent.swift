import Foundation
import SwiftUI


// Color extension with static colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
    
    static let backgroundStart = Color(hex: "FBE8A6")
    static let backgroundEnd = Color(hex: "FFD93D")
    static let accentGreen = Color(hex: "3DD598")
    static let errorRed = Color(hex: "FF6B6B")
    static let grainBrown = Color(hex: "CBA35C")
    static let deficitYellow = Color.yellow
    static let cardBackground = Color.white.opacity(0.95)
    static let shadowColor = Color.black.opacity(0.1)
    static let textPrimary = Color(hex: "333333")
    static let textSecondary = Color.gray.opacity(0.8)
    static let divider = Color.grainBrown.opacity(0.3)
}

// Font modifiers for premium typography
extension Font {
    static let premiumTitle = Font.system(size: 34, weight: .bold, design: .serif)
    static let premiumHeadline = Font.system(size: 20, weight: .semibold, design: .serif)
    static let premiumBody = Font.system(size: 16, weight: .regular, design: .rounded)
    static let premiumCaption = Font.system(size: 12, weight: .light, design: .rounded)
}

// Custom modifier for premium card style
struct PremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(24)
            .background(
                ZStack {
                    Color.cardBackground
                    LinearGradient(colors: [Color.white.opacity(0.05), Color.backgroundStart.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: Color.shadowColor, radius: 20, x: 0, y: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color.backgroundStart, Color.backgroundEnd], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
    }
}

struct PremiumButtonStyle2: ButtonStyle {
    let background: Color
    let foreground: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundColor(foreground)
            .padding()
            .frame(maxWidth: .infinity)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: background.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// Custom modifier for button style
//struct PremiumButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .font(Font.premiumHeadline)
//            .padding(.horizontal, 40)
//            .padding(.vertical, 16)
//            .background(
//                LinearGradient(colors: [Color.accentGreen, Color.accentGreen.opacity(0.85)], startPoint: .top, endPoint: .bottom)
//            )
//            .foregroundColor(.white)
//            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
//            .shadow(color: Color.accentGreen.opacity(0.5), radius: 10, x: 0, y: 5)
//            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
//            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
//    }
//}

// Data Models
enum BirdType: String, CaseIterable, Codable, Identifiable {
    var id: Self { self }
    case chicken = "Chicken"
    case duck = "Duck"
    case turkey = "Turkey"
    case quail = "Quail"
    case goose = "Goose"
}

enum Goal: String, CaseIterable, Codable, Identifiable {
    var id: Self { self }
    case eggLaying = "Egg Laying"
    case fattening = "Fattening"
    case growth = "Growth"
    case maintenance = "Maintenance"
}

enum AgeGroup: String, CaseIterable, Codable, Identifiable {
    var id: Self { self }
    case young = "Young"
    case adult = "Adult"
    case laying = "Laying"
    case broiler = "Broiler"
}

struct Nutrient: Codable, Hashable, Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let unit: String
}

struct Ingredient: Identifiable, Codable {
    let id = UUID()
    let name: String
    let photo: String? // Asset name or URL, e.g., "corn_icon"
    let nutrients: [String: Nutrient]
    let type: String // e.g., "Grain"
    let tag: String // e.g., "Energy"
    let pricePerKg: Double? // For cost calc, optional
}

struct IngredientAmount: Codable, Identifiable, Equatable {
    let id = UUID()
    let ingredient: Ingredient
    var amount: Double // g or %
    let unit: String
    
    static func ==(l: IngredientAmount, r: IngredientAmount) -> Bool {
        return l.id == r.id
    }
}

struct FeedMix: Identifiable, Codable {
    let id = UUID()
    var name: String
    let birdType: BirdType
    let goal: Goal
    let age: AgeGroup
    let weight: Double? // kg per bird
    var ingredients: [IngredientAmount]
    var calculatedNutrients: [String: Nutrient]
    let date: Date
    var costPerKg: Double?
}

// Completed Norms from NRC 1994 data
let nutrientNorms: [BirdType: [Goal: [AgeGroup: [String: (min: Double, max: Double)]]]] = [
    .chicken: [
        .growth: [
            .young: ["Energy": (2800, 3200), "Protein": (20, 23), "Calcium": (0.9, 1.0), "Phosphorus": (0.4, 0.45), "Lysine": (1.0, 1.1), "Methionine": (0.45, 0.5)],
            .broiler: ["Energy": (3000, 3200), "Protein": (18, 20), "Calcium": (0.85, 0.9), "Phosphorus": (0.35, 0.4), "Lysine": (0.85, 0.95), "Methionine": (0.4, 0.45)],
            .adult: ["Energy": (2800, 3000), "Protein": (14, 16), "Calcium": (0.8, 0.85), "Phosphorus": (0.3, 0.35), "Lysine": (0.7, 0.8), "Methionine": (0.3, 0.35)]
        ],
        .eggLaying: [
            .laying: ["Energy": (2600, 2900), "Protein": (15, 18), "Calcium": (3.25, 4.0), "Phosphorus": (0.25, 0.35), "Lysine": (0.69, 0.85), "Methionine": (0.3, 0.38)],
            .adult: ["Energy": (2600, 2900), "Protein": (14, 16), "Calcium": (2.75, 3.5), "Phosphorus": (0.25, 0.3), "Lysine": (0.6, 0.7), "Methionine": (0.25, 0.3)]
        ],
        .fattening: [
            .broiler: ["Energy": (3000, 3200), "Protein": (18, 22), "Calcium": (0.8, 0.9), "Phosphorus": (0.35, 0.4), "Lysine": (0.9, 1.0), "Methionine": (0.4, 0.45)],
            .young: ["Energy": (2900, 3100), "Protein": (20, 23), "Calcium": (0.9, 1.0), "Phosphorus": (0.4, 0.45), "Lysine": (1.0, 1.1), "Methionine": (0.45, 0.5)]
        ],
        .maintenance: [
            .adult: ["Energy": (2600, 2800), "Protein": (12, 14), "Calcium": (0.8, 1.0), "Phosphorus": (0.25, 0.3), "Lysine": (0.5, 0.6), "Methionine": (0.2, 0.25)]
        ]
    ],
    .duck: [
        .growth: [
            .young: ["Energy": (2800, 3000), "Protein": (20, 22), "Calcium": (0.65, 0.8), "Phosphorus": (0.3, 0.4), "Lysine": (0.9, 1.0), "Methionine": (0.4, 0.45)],
            .adult: ["Energy": (2700, 2900), "Protein": (16, 18), "Calcium": (0.6, 0.7), "Phosphorus": (0.3, 0.35), "Lysine": (0.7, 0.8), "Methionine": (0.3, 0.35)]
        ],
        .eggLaying: [
            .laying: ["Energy": (2600, 2800), "Protein": (16, 18), "Calcium": (2.0, 2.25), "Phosphorus": (0.3, 0.35), "Lysine": (0.7, 0.8), "Methionine": (0.3, 0.35)]
        ],
        .fattening: [
            .broiler: ["Energy": (2900, 3100), "Protein": (18, 20), "Calcium": (0.6, 0.7), "Phosphorus": (0.3, 0.35), "Lysine": (0.8, 0.9), "Methionine": (0.35, 0.4)]
        ],
        .maintenance: [
            .adult: ["Energy": (2500, 2700), "Protein": (14, 16), "Calcium": (0.5, 0.6), "Phosphorus": (0.25, 0.3), "Lysine": (0.6, 0.7), "Methionine": (0.25, 0.3)]
        ]
    ],
    .turkey: [
        .growth: [
            .young: ["Energy": (2800, 3000), "Protein": (26, 28), "Calcium": (1.2, 1.3), "Phosphorus": (0.6, 0.65), "Lysine": (1.5, 1.6), "Methionine": (0.55, 0.6)],
            .adult: ["Energy": (2900, 3100), "Protein": (20, 22), "Calcium": (0.8, 0.9), "Phosphorus": (0.4, 0.45), "Lysine": (1.0, 1.1), "Methionine": (0.4, 0.45)]
        ],
        .eggLaying: [
            .laying: ["Energy": (2800, 3000), "Protein": (14, 16), "Calcium": (2.25, 2.5), "Phosphorus": (0.35, 0.4), "Lysine": (0.8, 0.9), "Methionine": (0.35, 0.4)]
        ],
        .fattening: [
            .broiler: ["Energy": (3000, 3200), "Protein": (24, 26), "Calcium": (1.0, 1.1), "Phosphorus": (0.5, 0.55), "Lysine": (1.3, 1.4), "Methionine": (0.45, 0.5)]
        ],
        .maintenance: [
            .adult: ["Energy": (2700, 2900), "Protein": (12, 14), "Calcium": (0.75, 0.85), "Phosphorus": (0.3, 0.35), "Lysine": (0.7, 0.8), "Methionine": (0.3, 0.35)]
        ]
    ],
    .quail: [
        .growth: [
            .young: ["Energy": (2750, 2900), "Protein": (24, 27), "Calcium": (0.8, 1.0), "Phosphorus": (0.35, 0.45), "Lysine": (1.2, 1.3), "Methionine": (0.45, 0.5)],
            .adult: ["Energy": (2700, 2850), "Protein": (20, 22), "Calcium": (0.75, 0.85), "Phosphorus": (0.3, 0.35), "Lysine": (1.0, 1.1), "Methionine": (0.4, 0.45)]
        ],
        .eggLaying: [
            .laying: ["Energy": (2650, 2800), "Protein": (20, 21), "Calcium": (2.5, 2.75), "Phosphorus": (0.35, 0.4), "Lysine": (1.0, 1.1), "Methionine": (0.4, 0.45)]
        ],
        .fattening: [
            .broiler: ["Energy": (2750, 2900), "Protein": (24, 26), "Calcium": (0.8, 0.9), "Phosphorus": (0.35, 0.4), "Lysine": (1.1, 1.2), "Methionine": (0.45, 0.5)]
        ],
        .maintenance: [
            .adult: ["Energy": (2600, 2750), "Protein": (18, 20), "Calcium": (0.7, 0.8), "Phosphorus": (0.3, 0.35), "Lysine": (0.9, 1.0), "Methionine": (0.35, 0.4)]
        ]
    ],
    .goose: [
        .growth: [
            .young: ["Energy": (2700, 2900), "Protein": (20, 22), "Calcium": (0.65, 0.75), "Phosphorus": (0.3, 0.35), "Lysine": (0.9, 1.0), "Methionine": (0.4, 0.45)],
            .adult: ["Energy": (2600, 2800), "Protein": (15, 17), "Calcium": (0.6, 0.7), "Phosphorus": (0.25, 0.3), "Lysine": (0.7, 0.8), "Methionine": (0.3, 0.35)]
        ],
        .eggLaying: [
            .laying: ["Energy": (2600, 2800), "Protein": (15, 17), "Calcium": (2.25, 2.5), "Phosphorus": (0.3, 0.35), "Lysine": (0.7, 0.8), "Methionine": (0.3, 0.35)]
        ],
        .fattening: [
            .broiler: ["Energy": (2800, 3000), "Protein": (18, 20), "Calcium": (0.6, 0.7), "Phosphorus": (0.3, 0.35), "Lysine": (0.8, 0.9), "Methionine": (0.35, 0.4)]
        ],
        .maintenance: [
            .adult: ["Energy": (2500, 2700), "Protein": (12, 14), "Calcium": (0.5, 0.6), "Phosphorus": (0.25, 0.3), "Lysine": (0.6, 0.7), "Methionine": (0.25, 0.3)]
        ]
    ]
]

// Completed default ingredients from FAO/NRC data (averaged/typical values)
let defaultIngredients: [Ingredient] = [
    Ingredient(name: "Corn/Maize", photo: nil, nutrients: [
        "Protein": Nutrient(name: "Protein", value: 8.5, unit: "%"),
        "Fat": Nutrient(name: "Fat", value: 3.8, unit: "%"),
        "Fiber": Nutrient(name: "Fiber", value: 2.2, unit: "%"),
        "Ash": Nutrient(name: "Ash", value: 1.3, unit: "%"),
        "Calcium": Nutrient(name: "Calcium", value: 0.02, unit: "%"),
        "Phosphorus": Nutrient(name: "Phosphorus", value: 0.28, unit: "%"),
        "Energy": Nutrient(name: "Energy", value: 3350, unit: "kcal/kg"),
        "Lysine": Nutrient(name: "Lysine", value: 0.25, unit: "%"),
        "Methionine": Nutrient(name: "Methionine", value: 0.2, unit: "%")
    ], type: "Grain", tag: "Energy", pricePerKg: 0.2),
    Ingredient(name: "Wheat", photo: nil, nutrients: [
        "Protein": Nutrient(name: "Protein", value: 11.0, unit: "%"),
        "Fat": Nutrient(name: "Fat", value: 1.6, unit: "%"),
        "Fiber": Nutrient(name: "Fiber", value: 2.4, unit: "%"),
        "Ash": Nutrient(name: "Ash", value: 1.7, unit: "%"),
        "Calcium": Nutrient(name: "Calcium", value: 0.04, unit: "%"),
        "Phosphorus": Nutrient(name: "Phosphorus", value: 0.35, unit: "%"),
        "Energy": Nutrient(name: "Energy", value: 3100, unit: "kcal/kg"),
        "Lysine": Nutrient(name: "Lysine", value: 0.3, unit: "%"),
        "Methionine": Nutrient(name: "Methionine", value: 0.15, unit: "%")
    ], type: "Grain", tag: "Energy", pricePerKg: 0.25),
    Ingredient(name: "Barley", photo: nil, nutrients: [
        "Protein": Nutrient(name: "Protein", value: 10.5, unit: "%"),
        "Fat": Nutrient(name: "Fat", value: 1.9, unit: "%"),
        "Fiber": Nutrient(name: "Fiber", value: 4.7, unit: "%"),
        "Ash": Nutrient(name: "Ash", value: 2.3, unit: "%"),
        "Calcium": Nutrient(name: "Calcium", value: 0.06, unit: "%"),
        "Phosphorus": Nutrient(name: "Phosphorus", value: 0.35, unit: "%"),
        "Energy": Nutrient(name: "Energy", value: 2650, unit: "kcal/kg"),
        "Lysine": Nutrient(name: "Lysine", value: 0.35, unit: "%"),
        "Methionine": Nutrient(name: "Methionine", value: 0.17, unit: "%")
    ], type: "Grain", tag: "Energy", pricePerKg: 0.22),
    Ingredient(name: "Soybean Meal", photo: nil, nutrients: [
        "Protein": Nutrient(name: "Protein", value: 46.0, unit: "%"),
        "Fat": Nutrient(name: "Fat", value: 1.5, unit: "%"),
        "Fiber": Nutrient(name: "Fiber", value: 5.5, unit: "%"),
        "Ash": Nutrient(name: "Ash", value: 6.2, unit: "%"),
        "Calcium": Nutrient(name: "Calcium", value: 0.3, unit: "%"),
        "Phosphorus": Nutrient(name: "Phosphorus", value: 0.65, unit: "%"),
        "Energy": Nutrient(name: "Energy", value: 2250, unit: "kcal/kg"),
        "Lysine": Nutrient(name: "Lysine", value: 2.8, unit: "%"),
        "Methionine": Nutrient(name: "Methionine", value: 0.65, unit: "%")
    ], type: "Protein", tag: "Protein", pricePerKg: 0.4),
    Ingredient(name: "Fish Meal", photo: nil, nutrients: [
        "Protein": Nutrient(name: "Protein", value: 65.0, unit: "%"),
        "Fat": Nutrient(name: "Fat", value: 8.0, unit: "%"),
        "Fiber": Nutrient(name: "Fiber", value: 1.0, unit: "%"),
        "Ash": Nutrient(name: "Ash", value: 18.0, unit: "%"),
        "Calcium": Nutrient(name: "Calcium", value: 4.0, unit: "%"),
        "Phosphorus": Nutrient(name: "Phosphorus", value: 2.5, unit: "%"),
        "Energy": Nutrient(name: "Energy", value: 2800, unit: "kcal/kg"),
        "Lysine": Nutrient(name: "Lysine", value: 5.0, unit: "%"),
        "Methionine": Nutrient(name: "Methionine", value: 1.8, unit: "%")
    ], type: "Protein", tag: "Protein", pricePerKg: 1.0),
    Ingredient(name: "Oyster Shell", photo: nil, nutrients: [
        "Protein": Nutrient(name: "Protein", value: 0.0, unit: "%"),
        "Fat": Nutrient(name: "Fat", value: 0.0, unit: "%"),
        "Fiber": Nutrient(name: "Fiber", value: 0.0, unit: "%"),
        "Ash": Nutrient(name: "Ash", value: 95.0, unit: "%"),
        "Calcium": Nutrient(name: "Calcium", value: 38.0, unit: "%"),
        "Phosphorus": Nutrient(name: "Phosphorus", value: 0.1, unit: "%"),
        "Energy": Nutrient(name: "Energy", value: 0, unit: "kcal/kg"),
        "Lysine": Nutrient(name: "Lysine", value: 0.0, unit: "%"),
        "Methionine": Nutrient(name: "Methionine", value: 0.0, unit: "%")
    ], type: "Mineral", tag: "Mineral", pricePerKg: 0.1),
    Ingredient(name: "Blood Meal", photo: nil, nutrients: [
        "Protein": Nutrient(name: "Protein", value: 85.0, unit: "%"),
        "Fat": Nutrient(name: "Fat", value: 1.0, unit: "%"),
        "Fiber": Nutrient(name: "Fiber", value: 1.0, unit: "%"),
        "Ash": Nutrient(name: "Ash", value: 4.0, unit: "%"),
        "Calcium": Nutrient(name: "Calcium", value: 0.3, unit: "%"),
        "Phosphorus": Nutrient(name: "Phosphorus", value: 0.3, unit: "%"),
        "Energy": Nutrient(name: "Energy", value: 3000, unit: "kcal/kg"),
        "Lysine": Nutrient(name: "Lysine", value: 7.5, unit: "%"),
        "Methionine": Nutrient(name: "Methionine", value: 0.8, unit: "%")
    ], type: "Protein", tag: "Protein", pricePerKg: 0.8),
    Ingredient(name: "Feather Meal", photo: nil, nutrients: [
        "Protein": Nutrient(name: "Protein", value: 85.0, unit: "%"),
        "Fat": Nutrient(name: "Fat", value: 3.0, unit: "%"),
        "Fiber": Nutrient(name: "Fiber", value: 2.0, unit: "%"),
        "Ash": Nutrient(name: "Ash", value: 4.0, unit: "%"),
        "Calcium": Nutrient(name: "Calcium", value: 0.2, unit: "%"),
        "Phosphorus": Nutrient(name: "Phosphorus", value: 0.3, unit: "%"),
        "Energy": Nutrient(name: "Energy", value: 2500, unit: "kcal/kg"),
        "Lysine": Nutrient(name: "Lysine", value: 2.0, unit: "%"),
        "Methionine": Nutrient(name: "Methionine", value: 0.6, unit: "%")
    ], type: "Protein", tag: "Protein", pricePerKg: 0.5),
    Ingredient(name: "Meat and Bone Meal", photo: nil, nutrients: [
        "Protein": Nutrient(name: "Protein", value: 50.0, unit: "%"),
        "Fat": Nutrient(name: "Fat", value: 10.0, unit: "%"),
        "Fiber": Nutrient(name: "Fiber", value: 2.5, unit: "%"),
        "Ash": Nutrient(name: "Ash", value: 30.0, unit: "%"),
        "Calcium": Nutrient(name: "Calcium", value: 10.0, unit: "%"),
        "Phosphorus": Nutrient(name: "Phosphorus", value: 5.0, unit: "%"),
        "Energy": Nutrient(name: "Energy", value: 2000, unit: "kcal/kg"),
        "Lysine": Nutrient(name: "Lysine", value: 2.5, unit: "%"),
        "Methionine": Nutrient(name: "Methionine", value: 0.7, unit: "%")
    ], type: "Protein", tag: "Protein", pricePerKg: 0.6),
    Ingredient(name: "Sunflower Meal", photo: nil, nutrients: [
        "Protein": Nutrient(name: "Protein", value: 34.0, unit: "%"),
        "Fat": Nutrient(name: "Fat", value: 1.5, unit: "%"),
        "Fiber": Nutrient(name: "Fiber", value: 24.0, unit: "%"),
        "Ash": Nutrient(name: "Ash", value: 7.0, unit: "%"),
        "Calcium": Nutrient(name: "Calcium", value: 0.4, unit: "%"),
        "Phosphorus": Nutrient(name: "Phosphorus", value: 1.0, unit: "%"),
        "Energy": Nutrient(name: "Energy", value: 1500, unit: "kcal/kg"),
        "Lysine": Nutrient(name: "Lysine", value: 1.2, unit: "%"),
        "Methionine": Nutrient(name: "Methionine", value: 0.7, unit: "%")
    ], type: "Protein", tag: "Protein", pricePerKg: 0.3),
    Ingredient(name: "Canola Meal", photo: nil, nutrients: [
        "Protein": Nutrient(name: "Protein", value: 36.0, unit: "%"),
        "Fat": Nutrient(name: "Fat", value: 3.5, unit: "%"),
        "Fiber": Nutrient(name: "Fiber", value: 12.0, unit: "%"),
        "Ash": Nutrient(name: "Ash", value: 7.0, unit: "%"),
        "Calcium": Nutrient(name: "Calcium", value: 0.7, unit: "%"),
        "Phosphorus": Nutrient(name: "Phosphorus", value: 1.1, unit: "%"),
        "Energy": Nutrient(name: "Energy", value: 2000, unit: "kcal/kg"),
        "Lysine": Nutrient(name: "Lysine", value: 2.0, unit: "%"),
        "Methionine": Nutrient(name: "Methionine", value: 0.7, unit: "%")
    ], type: "Protein", tag: "Protein", pricePerKg: 0.35)
    // Add more if needed
]
