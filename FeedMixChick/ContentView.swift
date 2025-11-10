import SwiftUI
import PDFKit
import Speech
import UserNotifications
import CoreImage.CIFilterBuiltins
import WebKit
import AppsFlyerLib
import AppTrackingTransparency
import FirebaseCore
import FirebaseMessaging
import Combine

@main
struct PoultryFeedApp: App {
    
    @UIApplicationDelegateAdaptor(ApplicationDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            LaunchScreen()
        }
    }
}

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

// Custom modifier for button style
struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Font.premiumHeadline)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [Color.accentGreen, Color.accentGreen.opacity(0.85)], startPoint: .top, endPoint: .bottom)
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.accentGreen.opacity(0.5), radius: 10, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

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

// Enhanced NutrientChart with premium look
struct NutrientChart: View {
    let nutrients: [String: Nutrient]
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width / CGFloat(max(nutrients.count, 1))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(nutrients.keys.sorted(), id: \.self) { key in
                        VStack(spacing: 8) {
                            let height = CGFloat(nutrients[key]!.value) * 3 // Enhanced scale
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LinearGradient(colors: [Color.accentGreen, Color.grainBrown], startPoint: .top, endPoint: .bottom))
                                .frame(width: width - 32, height: animate ? height : 0)
                                .shadow(color: Color.shadowColor, radius: 8)
                            Text(key)
                                .font(Font.premiumCaption)
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(height: 180)
        .background(Color.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.shadowColor, radius: 15)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animate = true
            }
        }
    }
}

// ContentView with premium background and tab bar
struct ContentView: View {
    @State private var selectedTab = 0
    let backgroundGradient = LinearGradient(colors: [Color.backgroundStart, Color.backgroundEnd], startPoint: .top, endPoint: .bottom)
    
    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()
            TabView(selection: $selectedTab) {
                HomeView(selectedTab: $selectedTab)
                    .tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
                CalculatorView()
                    .tabItem { Label("Calculator", systemImage: "scalemass.fill") }.tag(1)
                IngredientsView()
                    .tabItem { Label("Ingredients", systemImage: "leaf.fill") }.tag(2)
                ReportsView()
                    .tabItem { Label("Reports", systemImage: "chart.bar.fill") }.tag(3)
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(4)
            }
            .accentColor(Color.accentGreen)
            .onAppear {
                let appearance = UITabBarAppearance()
                appearance.backgroundEffect = UIBlurEffect(style: .light)
                appearance.backgroundColor = UIColor(Color.backgroundStart.opacity(0.6))
                UITabBar.appearance().scrollEdgeAppearance = appearance
                UITabBar.appearance().standardAppearance = appearance
            }
        }
    }
}

// HomeView premium
struct HomeView: View {
    @Binding var selectedTab: Int
    @AppStorage("savedMixes") private var savedMixesData: Data = Data()
    private var savedMixes: [FeedMix] {
        (try? JSONDecoder().decode([FeedMix].self, from: savedMixesData)) ?? []
    }
    let tips = [
        "Add fish oil in winter for vitamin D",
        "Ensure calcium for layers to prevent soft shells",
        "Balance protein for optimal growth",
        "Monitor phosphorus to avoid deficiencies"
    ]
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 50
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                HStack(spacing: 16) {
                    Image(systemName: "leaf.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(Color.accentGreen)
                        .shadow(color: Color.shadowColor, radius: 5)
                    Text("Poultry Feed Premium")
                        .font(Font.premiumTitle)
                        .foregroundColor(Color.grainBrown)
                }
                .padding(.top, 32)
                .opacity(opacity)
                .offset(y: offset)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.8)) {
                        opacity = 1
                        offset = 0
                    }
                }
                
                if let lastMix = savedMixes.last {
                    VStack(spacing: 16) {
                        Text("Last Mix: \(lastMix.name)")
                            .font(Font.premiumHeadline)
                            .foregroundColor(Color.textPrimary)
                        Text("For \(lastMix.birdType.rawValue), \(lastMix.goal.rawValue)")
                            .font(Font.premiumBody)
                            .foregroundColor(Color.textSecondary)
                        NutrientChart(nutrients: lastMix.calculatedNutrients)
                    }
                    .modifier(PremiumCardModifier())
                }
                
                VStack(spacing: 16) {
                    Text("Tip of the Day")
                        .font(Font.premiumHeadline)
                        .foregroundColor(Color.textPrimary)
                    Text(tips.randomElement() ?? "")
                        .font(Font.premiumBody)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.textSecondary)
                }
                .modifier(PremiumCardModifier())
                
                Button(action: {
                    withAnimation(.easeInOut) {
                        selectedTab = 1
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                        Text("New Calculation")
                    }
                }
                .buttonStyle(PremiumButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // For tab bar
        }
    }
}

// CalculatorView premium
struct CalculatorView: View {
    @State private var birdType: BirdType = .chicken
    @State private var goal: Goal = .eggLaying
    @State private var age: AgeGroup = .adult
    @State private var weight: String = ""
    @State private var ingredientAmounts: [IngredientAmount] = []
    @State private var showIngredientPicker = false
    @State private var unit = "%"
    @AppStorage("unit") private var globalUnit = "%"
    
    @State private var calculatedNutrients: [String: Nutrient] = [:]
    @State private var recommendations: [String] = []
    @State private var totalPercentage: Double = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var costPerKg: Double = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("Bird Type")
                        .font(Font.premiumCaption)
                        .foregroundColor(Color.textSecondary)
                    Picker("Bird Type", selection: $birdType) {
                        ForEach(BirdType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(Color.accentGreen)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: Color.shadowColor, radius: 5)
                }
                
                VStack(spacing: 16) {
                    Text("Goal")
                        .font(Font.premiumCaption)
                        .foregroundColor(Color.textSecondary)
                    Picker("Goal", selection: $goal) {
                        ForEach(Goal.allCases) { goal in
                            Text(goal.rawValue).tag(goal)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(Color.accentGreen)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: Color.shadowColor, radius: 5)
                }
                
                VStack(spacing: 16) {
                    Text("Age Group")
                        .font(Font.premiumCaption)
                        .foregroundColor(Color.textSecondary)
                    Picker("Age Group", selection: $age) {
                        ForEach(AgeGroup.allCases) { age in
                            Text(age.rawValue).tag(age)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(Color.accentGreen)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: Color.shadowColor, radius: 5)
                }
                
                TextField("Average Bird Weight (kg, optional)", text: $weight)
                    .keyboardType(.decimalPad)
                    .font(Font.premiumBody)
                    .padding()
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: Color.shadowColor, radius: 5)
                
                Button("Add Ingredient") {
                    showIngredientPicker = true
                }
                .buttonStyle(PremiumButtonStyle())
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
                    ForEach($ingredientAmounts) { $ia in
                        HStack(spacing: 12) {
                            Image(systemName: "leaf.arrow.triangle.circlepath")
                                .foregroundColor(Color.accentGreen)
                                .font(.system(size: 20))
                            Text(ia.ingredient.name)
                                .font(Font.premiumBody)
                                .foregroundColor(Color.textPrimary)
                            if unit == "%" {
                                Slider(value: $ia.amount, in: 0...100, step: 0.5)
                                    .accentColor(Color.accentGreen)
                            } else {
                                TextField("Amount", value: $ia.amount, format: .number)
                                    .font(Font.premiumBody)
                                    .padding(8)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            Text(unit)
                                .font(Font.premiumCaption)
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(16)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.shadowColor, radius: 10)
                    }
                }
                
                if totalPercentage != 100 && unit == "%" {
                    Text("Total: \(totalPercentage, specifier: "%.1f")%")
                        .font(Font.premiumBody)
                        .foregroundColor(Color.errorRed)
                }
                
                VStack(spacing: 16) {
                    Text("Nutrients")
                        .font(Font.premiumHeadline)
                        .foregroundColor(Color.textPrimary)
                    ForEach(calculatedNutrients.keys.sorted(), id: \.self) { key in
                        let nutrient = calculatedNutrients[key]!
                        let color = getHighlightColor(for: nutrient, birdType: birdType, goal: goal, age: age)
                        HStack {
                            Text("\(key):")
                                .foregroundColor(Color.textSecondary)
                            Text("\(nutrient.value, specifier: "%.2f") \(nutrient.unit)")
                                .foregroundColor(color)
                                .font(Font.premiumBody.bold())
                        }
                        Divider().background(Color.divider)
                    }
                }
                .modifier(PremiumCardModifier())
                
                if !recommendations.isEmpty {
                    VStack(spacing: 16) {
                        Text("Recommendations")
                            .font(Font.premiumHeadline)
                            .foregroundColor(Color.textPrimary)
                        ForEach(recommendations, id: \.self) { rec in
                            Text(rec)
                                .font(Font.premiumBody)
                                .foregroundColor(Color.errorRed)
                        }
                    }
                    .modifier(PremiumCardModifier())
                }
                
                Text("Cost per kg: \(costPerKg, specifier: "%.2f") \(currency)")
                    .font(Font.premiumBody.bold())
                    .foregroundColor(Color.accentGreen)
                
                HStack(spacing: 24) {
                    Button("Auto Suggest") {
                        autoSuggest()
                    }
                    .buttonStyle(PremiumButtonStyle())
                    
                    Button("Save") {
                        if validateTotal() {
                            saveMix()
                        } else {
                            alertMessage = unit == "%" ? "Total must be 100%" : "Enter valid amounts"
                            showAlert = true
                        }
                    }
                    .buttonStyle(PremiumButtonStyle())
                }
                
                Button("Voice Input") {
                    startVoiceRecognition()
                }
                .buttonStyle(PremiumButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    opacity = 1
                }
            }
        }
        .sheet(isPresented: $showIngredientPicker) {
            IngredientPickerView(selected: $ingredientAmounts)
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK") {}
        }
        .onAppear { unit = globalUnit }
        .onChange(of: ingredientAmounts) { _ in
            calculateAll()
        }
        .onChange(of: unit) { _ in calculateAll() }
    }
    
    private func calculateAll() {
        calculateNutrients()
        calculateCost()
    }
    
    private func validateTotal() -> Bool {
        if unit == "%" {
            totalPercentage = ingredientAmounts.reduce(0) { $0 + $1.amount }
            return abs(totalPercentage - 100) < 0.1
        }
        return ingredientAmounts.allSatisfy { $0.amount > 0 }
    }
    
    private func calculateNutrients() {
        var totals: [String: Double] = [:]
        var totalAmount = 0.0
        for ia in ingredientAmounts {
            var amt = ia.amount
            if unit == "%" { amt /= 100 }
            totalAmount += amt
            for (key, nut) in ia.ingredient.nutrients {
                totals[key, default: 0] += nut.value * amt
            }
        }
        if totalAmount == 0 { return }
        
        for key in totals.keys {
            calculatedNutrients[key] = Nutrient(name: key, value: totals[key]! / totalAmount, unit: "%") // For % nutrients
        }
        
        // Energy is additive per kg
        if let energy = totals["Energy"] {
            calculatedNutrients["Energy"] = Nutrient(name: "Energy", value: energy, unit: "kcal/kg") // Already weighted
        }
        
        checkNormsAndRecommend()
    }
    
    private func checkNormsAndRecommend() {
        recommendations = []
        if let norms = nutrientNorms[birdType]?[goal]?[age] {
            for (key, (min, max)) in norms {
                if let val = calculatedNutrients[key]?.value {
                    if val < min { recommendations.append("Deficit in \(key): add sources.") ; scheduleNotification(title: "Nutrient Alert", body: "Deficit in \(key)") }
                    if val > max { recommendations.append("Excess in \(key): reduce.") ; scheduleNotification(title: "Nutrient Alert", body: "Excess in \(key)") }
                } else {
                    recommendations.append("\(key) not calculated.")
                }
            }
        }
    }
    
    private func calculateCost() {
        var totalCost = 0.0
        var totalAmount = 0.0
        for ia in ingredientAmounts {
            if let price = ia.ingredient.pricePerKg {
                var amt = ia.amount / (unit == "%" ? 100 : 1) // kg fraction
                totalCost += price * amt
                totalAmount += amt
            }
        }
        costPerKg = totalAmount > 0 ? totalCost / totalAmount : 0
    }
    
    private func getHighlightColor(for nutrient: Nutrient, birdType: BirdType, goal: Goal, age: AgeGroup) -> Color {
        if let norms = nutrientNorms[birdType]?[goal]?[age]?[nutrient.name] {
            let val = nutrient.value
            if val >= norms.min && val <= norms.max { return Color.accentGreen }
            if val < norms.min { return Color.deficitYellow }
            return Color.errorRed
        }
        return Color.textPrimary
    }
    
    @State var savedMixesData: Data!
    
    private func saveMix() {
        var mix = FeedMix(name: "Mix \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))", birdType: birdType, goal: goal, age: age, weight: Double(weight), ingredients: ingredientAmounts, calculatedNutrients: calculatedNutrients, date: Date())
        mix.costPerKg = costPerKg
        var mixes = (try? JSONDecoder().decode([FeedMix].self, from: savedMixesData)) ?? []
        mixes.append(mix)
        savedMixesData = (try? JSONEncoder().encode(mixes)) ?? Data()
    }
    
    private func createPDFData(for nutrients: [String: Nutrient], recommendations: [String], mix: FeedMix) -> Data {
        let pdfMetaData = [kCGPDFContextCreator as String: "Poultry Feed App"]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        return renderer.pdfData { context in
            context.beginPage()
            let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]
            var y: CGFloat = 20
            "Bird: \(mix.birdType.rawValue), Goal: \(mix.goal.rawValue), Age: \(mix.age.rawValue)".draw(at: CGPoint(x: 20, y: y), withAttributes: attributes)
            y += 20
            for (key, nut) in nutrients {
                "\(key): \(nut.value) \(nut.unit)".draw(at: CGPoint(x: 20, y: y), withAttributes: attributes)
                y += 15
            }
            y += 20
            "Recommendations:".draw(at: CGPoint(x: 20, y: y), withAttributes: attributes)
            y += 15
            for rec in recommendations {
                rec.draw(at: CGPoint(x: 20, y: y), withAttributes: attributes)
                y += 15
            }
        }
    }
    
    private func startVoiceRecognition() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status == .authorized {
                let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
                // Implement audio recording and recognition here
                // For example, parse "Create feed for chickens egg laying adult"
                // Set birdType = .chicken, goal = .eggLaying, age = .adult
            }
        }
    }
    
    private func autoSuggest() {
        if let norms = nutrientNorms[birdType]?[goal]?[age] {
            // Simple suggestion: if protein low, add soybean
            if let protNorm = norms["Protein"]?.min, let currProt = calculatedNutrients["Protein"]?.value, currProt < protNorm {
                if let soy = defaultIngredients.first(where: { $0.name == "Soybean Meal" }) {
                    ingredientAmounts.append(IngredientAmount(ingredient: soy, amount: 10, unit: unit))
                }
            }
            // Add similar for other nutrients
            calculateAll()
        }
    }
    
    @AppStorage("currency") private var currency = "USD"
}

// IngredientPickerView premium
struct IngredientPickerView: View {
    @Binding var selected: [IngredientAmount]
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    var filtered: [Ingredient] {
        defaultIngredients.filter { searchText.isEmpty || $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filtered) { ing in
                    Button(action: {
                        selected.append(IngredientAmount(ingredient: ing, amount: 0, unit: "%"))
                        dismiss()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "plus.square.fill.on.square.fill")
                                .foregroundColor(Color.accentGreen)
                                .font(.system(size: 24))
                            Text(ing.name)
                                .font(Font.premiumBody)
                                .foregroundColor(Color.textPrimary)
                        }
                    }
                    .listRowBackground(Color.cardBackground)
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

// IngredientsView premium
struct IngredientsView: View {
    @State private var searchText = ""
    @State private var ingredients = defaultIngredients
    @State private var showAddCustom = false
    
    var filtered: [Ingredient] {
        ingredients.filter { searchText.isEmpty || $0.name.lowercased().contains(searchText.lowercased()) || $0.type.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filtered) { ing in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            if let photo = ing.photo {
                                Image(photo)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                    .shadow(color: Color.shadowColor, radius: 5)
                            } else {
                                Image(systemName: "leaf.circle.fill")
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(Color.accentGreen)
                                    .shadow(color: Color.shadowColor, radius: 5)
                            }
                            VStack(alignment: .leading) {
                                Text(ing.name)
                                    .font(Font.premiumHeadline)
                                    .foregroundColor(Color.textPrimary)
                                Text("Type: \(ing.type), Tag: \(ing.tag)")
                                    .font(Font.premiumCaption)
                                    .foregroundColor(Color.accentGreen)
                            }
                        }
                        ForEach(ing.nutrients.values.sorted(by: { $0.name < $1.name }), id: \.id) { nut in
                            HStack {
                                Text("\(nut.name):")
                                    .foregroundColor(Color.textSecondary)
                                Spacer()
                                Text("\(nut.value, specifier: "%.2f") \(nut.unit)")
                                    .foregroundColor(Color.textPrimary)
                            }
                            .font(Font.premiumBody)
                        }
                    }
                    .padding(16)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
                    .shadow(color: Color.shadowColor, radius: 10)
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Ingredients Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Add Custom") { showAddCustom = true }
            }
        }
        .sheet(isPresented: $showAddCustom) {
            VStack(spacing: 24) {
                Text("Add Custom Ingredient")
                    .font(Font.premiumTitle)
                    .foregroundColor(Color.grainBrown)
                TextField("Name", text: .constant(""))
                    .font(Font.premiumBody)
                    .padding()
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                // Add more fields for nutrients, type, etc.
                Button("Save") {
                    // Implement save custom ingredient
                }
                .buttonStyle(PremiumButtonStyle())
            }
            .padding()
        }
    }
}

// ReportsView premium
struct ReportsView: View {
    @AppStorage("savedMixes") private var savedMixesData: Data = Data()
    private var savedMixes: [FeedMix] {
        (try? JSONDecoder().decode([FeedMix].self, from: savedMixesData)) ?? []
    }
    @State private var flockSize: String = ""
    @State private var selectedMix: FeedMix?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                List(savedMixes) { mix in
                    Button(mix.name) {
                        selectedMix = mix
                    }
                    .font(Font.premiumBody)
                    .listRowBackground(Color.cardBackground.clipShape(RoundedRectangle(cornerRadius: 15)))
                }
                
                if let mix = selectedMix {
                    VStack(spacing: 16) {
                        Text(mix.name)
                            .font(Font.premiumHeadline)
                        NutrientChart(nutrients: mix.calculatedNutrients)
                    }
                    .modifier(PremiumCardModifier())
                }
                
                TextField("Flock Size", text: $flockSize)
                    .keyboardType(.numberPad)
                    .font(Font.premiumBody)
                    .padding()
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .shadow(color: Color.shadowColor, radius: 5)
                
                if let size = Double(flockSize), let mix = selectedMix, let weight = mix.weight {
                    let dailyNeed = size * weight * 0.12
                    Text("Daily Feed: \(dailyNeed, specifier: "%.2f") kg")
                        .font(Font.premiumBody.bold())
                        .foregroundColor(Color.accentGreen)
                    if let cost = mix.costPerKg {
                        Text("Daily Cost: $\(dailyNeed * cost, specifier: "%.2f")")
                            .font(Font.premiumBody.bold())
                            .foregroundColor(Color.grainBrown)
                    }
                }
            }
            .padding(.horizontal, 20)
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// SettingsView premium
struct SettingsView: View {
    @AppStorage("unit") private var unit = "%"
    @AppStorage("currency") private var currency = "USD"
    
    var body: some View {
        Form {
            Section(header: Text("Units").font(Font.premiumCaption).foregroundColor(Color.grainBrown)) {
                Picker("Measurement", selection: $unit) {
                    Text("%").tag("%")
                    Text("grams").tag("g")
                    Text("kg").tag("kg")
                }
                .pickerStyle(.menu)
            }
            
            Section(header: Text("Currency").font(Font.premiumCaption).foregroundColor(Color.grainBrown)) {
                TextField("Currency Symbol", text: $currency)
                    .font(Font.premiumBody)
            }
            
            Toggle("Enable Reminders", isOn: .constant(true))
                .font(Font.premiumBody)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Notifications
func scheduleNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request) { error in
        if let error = error { print(error) }
    }
}

// QR View
struct QRView: View {
    let data: String
    
    var body: some View {
        if let qr = generateQR(from: data) {
            Image(uiImage: qr)
                .resizable()
                .scaledToFit()
        }
    }
    
    func generateQR(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        if let outputImage = filter.outputImage, let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}

// MARK: - Core State Manager
final class FarmStarter: ObservableObject {
    
    @Published var currentState: StateType = .loading
    @Published var contentTrail: URL?
    @Published var showPermissionPrompt = false
    
    private var attribInfo: [AnyHashable: Any] = [:]
    private var deeplinkValues: [String: Any] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private var firstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "hasLaunched")
    }
    
    // MARK: - State Types
    enum StateType {
        case loading
        case henView
        case fallback
        case offline
    }
    
    // MARK: - Init & Lifecycle
    init() {
        subscribeToConversionData()
        monitorNetworkReachability()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Conversion Data
    private func subscribeToConversionData() {
        NotificationCenter.default
            .publisher(for: Notification.Name("ConversionDataReceived"))
            .compactMap { $0.userInfo?["conversionData"] as? [AnyHashable: Any] }
            .sink { [weak self] data in
                self?.attribInfo = data
                self?.evaluateLaunchFlow()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: Notification.Name("deeplink_values"))
            .compactMap { $0.userInfo?["deeplinksData"] as? [String: Any] }
            .sink { [weak self] data in
                self?.deeplinkValues = data
            }
            .store(in: &cancellables)
    }
    
    @objc private func evaluateLaunchFlow() {
        guard !attribInfo.isEmpty else {
            fallbackOnMissingConfig()
            return
        }
        
        if UserDefaults.standard.string(forKey: "app_mode") == "Funtik" {
            transition(to: .fallback)
            return
        }
        
        if firstLaunch, attribInfo["af_status"] as? String == "Organic" {
            triggerOrganicValidation()
            return
        }
        
        if let tempLink = UserDefaults.standard.string(forKey: "temp_url"), !tempLink.isEmpty {
            contentTrail = URL(string: tempLink)
            transition(to: .henView)
            return
        }
        
        if contentTrail == nil {
            shouldShowNotificationPrompt() ? displayPrompt() : initiateConfigurationCall()
        }
    }
    
    // MARK: - Network Monitoring
    private func monitorNetworkReachability() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            if path.status != .satisfied {
                self.handleNetworkLoss()
            }
        }
        monitor.start(queue: .global())
    }
    
    private func handleNetworkLoss() {
        let mode = UserDefaults.standard.string(forKey: "app_mode")
        mode == "HenView" ? transition(to: .offline) : activateFallbackMode()
    }
    
    // MARK: - Organic Install Validation
    private func triggerOrganicValidation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            Task { await self.performOrganicCheck() }
        }
    }
    
    private func performOrganicCheck() async {
        let request = OrganicValidationRequest()
            .withAppId(AppKeys.appId)
            .withDevKey(AppKeys.devKey)
            .withDeviceId(AppsFlyerLib.shared().getAppsFlyerUID())
        
        guard let url = request.buildURL() else {
            activateFallbackMode()
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            try await handleOrganicResponse(data: data, response: response)
        } catch {
            activateFallbackMode()
        }
    }
    
    private func handleOrganicResponse(data: Data, response: URLResponse) async throws {
        guard
            let http = response as? HTTPURLResponse,
            http.statusCode == 200,
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            activateFallbackMode()
            return
        }
        
        var merged = attribInfo
        
        // Добавляем deep link только если он есть и ключей нет
        for (key, value) in deeplinkValues {
            if merged[key] == nil {
                merged[key] = value
            }
        }
        
        print("[AFSDK] recall \(merged)")
        await MainActor.run {
            self.attribInfo = merged
            self.initiateConfigurationCall()
        }
    }
    
    // MARK: - Configuration Request
    func initiateConfigurationCall() {
        guard let endpoint = URL(string: "https://feedmiix.com/config.php") else {
            fallbackOnMissingConfig()
            return
        }
        
        var payload = attribInfo
        payload["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        payload["bundle_id"] = Bundle.main.bundleIdentifier ?? "com.example.app"
        payload["os"] = "iOS"
        payload["store_id"] = "id6753303972"
        payload["locale"] = Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"
        payload["push_token"] = UserDefaults.standard.string(forKey: "fcm_token") ?? Messaging.messaging().fcmToken
        payload["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            fallbackOnMissingConfig()
            return
        }
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            if error != nil || data == nil {
                self.fallbackOnMissingConfig()
                return
            }
            
            guard
                let json = try? JSONSerialization.jsonObject(with: data!) as? [String: Any],
                let success = json["ok"] as? Bool, success,
                let urlStr = json["url"] as? String,
                let expires = json["expires"] as? TimeInterval
            else {
                self.activateFallbackMode()
                return
            }
            
            DispatchQueue.main.async {
                self.persistConfig(url: urlStr, expires: expires)
                self.contentTrail = URL(string: urlStr)
                self.transition(to: .henView)
            }
        }.resume()
    }
    
    private func persistConfig(url: String, expires: TimeInterval) {
        UserDefaults.standard.set(url, forKey: "saved_trail")
        UserDefaults.standard.set(expires, forKey: "saved_expires")
        UserDefaults.standard.set("HenView", forKey: "app_mode")
        UserDefaults.standard.set(true, forKey: "hasLaunched")
    }
    
    // MARK: - Fallback & Offline
    private func fallbackOnMissingConfig() {
        if let saved = UserDefaults.standard.string(forKey: "saved_trail"),
           let url = URL(string: saved) {
            contentTrail = url
            currentState = .henView
        } else {
            activateFallbackMode()
        }
    }
    
    private func activateFallbackMode() {
        UserDefaults.standard.set("Funtik", forKey: "app_mode")
        UserDefaults.standard.set(true, forKey: "hasLaunched")
        transition(to: .fallback)
    }
    
    private func shouldShowNotificationPrompt() -> Bool {
        guard
            let last = UserDefaults.standard.object(forKey: "last_notification_ask") as? Date,
            Date().timeIntervalSince(last) >= 259200
        else { return false }
        return true
    }
    
    private func displayPrompt() {
        showPermissionPrompt = true
    }
    
    func dismissPrompt() {
        UserDefaults.standard.set(Date(), forKey: "last_notification_ask")
        showPermissionPrompt = false
        initiateConfigurationCall()
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                UserDefaults.standard.set(granted, forKey: "accepted_notifications")
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    UserDefaults.standard.set(true, forKey: "system_close_notifications")
                }
                self?.initiateConfigurationCall()
                self?.showPermissionPrompt = false
            }
        }
    }
    
    private func transition(to state: StateType) {
        DispatchQueue.main.async {
            self.currentState = state
        }
    }
}

struct AppKeys {
    static let appId = "6754925371"
    static let devKey = "A6ZJvG9oyq5Cqx7K5v3ycZ"
}

struct OrganicValidationRequest {
    private let baseURL = "https://gcdsdk.appsflyer.com/install_data/v4.0/"
    private var appId: String = ""
    private var devKey: String = ""
    private var deviceId: String = ""
    
    func withAppId(_ id: String) -> Self { copy(\.appId, to: id) }
    func withDevKey(_ key: String) -> Self { copy(\.devKey, to: key) }
    func withDeviceId(_ id: String) -> Self { copy(\.deviceId, to: id) }
    
    func buildURL() -> URL? {
        guard !appId.isEmpty, !devKey.isEmpty, !deviceId.isEmpty else { return nil }
        var components = URLComponents(string: baseURL + "id\(appId)")!
        components.queryItems = [
            .init(name: "devkey", value: devKey),
            .init(name: "device_id", value: deviceId)
        ]
        return components.url
    }
    
    private func copy<T>(_ path: WritableKeyPath<Self, T>, to value: T) -> Self {
        var updated = self
        updated[keyPath: path] = value
        return updated
    }
}

// MARK: - Launch Screen
struct LaunchScreen: View {
    @StateObject private var flow = FarmStarter()
    
    var body: some View {
        ZStack {
            if flow.currentState == .loading || flow.showPermissionPrompt {
                LoadingScreen()
            }
            
            if flow.showPermissionPrompt {
                PermissionPrompt(
                    onAccept: flow.requestPermission,
                    onDecline: flow.dismissPrompt
                )
            } else {
                primaryContent
            }
        }
    }
    
    @ViewBuilder
    private var primaryContent: some View {
        switch flow.currentState {
        case .loading:
            EmptyView()
        case .henView:
            if flow.contentTrail != nil {
                PrimaryInterface()
            } else {
                ContentView()
            }
        case .fallback:
            ContentView()
        case .offline:
            OfflineScreen()
        }
    }
}


struct LoadingScreen: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("hen_world_splash_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Text("LOADING APP...")
                        .font(.custom("Inter-Regular_ExtraBold", size: 26))
                        .foregroundColor(.white)
                    InfinityBar()
                        .padding(.horizontal, 32)
                    Spacer().frame(height: 80)
                }
            }
        }.ignoresSafeArea()
    }
}

struct InfinityBar: View {
    @State private var offset: CGFloat = 0
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2))
                Capsule().fill(Color(hex: "#FFFDBD"))
                    .frame(width: animate ? 100 : 70)
                    .offset(x: offset)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)
            }
            .clipShape(Capsule())
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: true)) {
                    offset = geo.size.width
                }
                animate = true
            }
        }
        .frame(height: 8)
        .padding(.horizontal, 32)
    }
}

struct OfflineScreen: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("hen_world_splash_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Text("NO INTERNET CONNECTION! PLEASE CHECK YOUR NETWORK AND COME BACK!")
                        .font(.custom("Inter-Regular_Bold", size: 24))
                        .foregroundColor(Color(red: 255/255, green: 221/255, blue: 0))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(red: 13/255, green: 21/255, blue: 45/255))
                        .padding(.horizontal, 24)
                    Spacer().frame(height: 100)
                }
            }
        }.ignoresSafeArea()
    }
}

struct PermissionPrompt: View {
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            ZStack {
                Image("hen_world_splash_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .ignoresSafeArea()
                
                VStack(spacing: isLandscape ? 5 : 10) {
                    Spacer()
                    Text("Allow notifications about bonuses and promos".uppercased())
                        .font(.custom("Inter-Regular_ExtraBold", size: 18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Text("Stay tuned with best offers from our casino")
                        .font(.custom("Inter-Regular_Bold", size: 15))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 52)
                        .padding(.top, 4)
                    
                    Button(action: onAccept) {
                        ZStack {
                            Image("button_bg")
                                .resizable()
                                .frame(height: 60)
                            
                            Text("Yes, I Want Bonuses!")
                                .font(.custom("Inter-Regular_ExtraBold", size: 16))
                                .foregroundColor(Color(hex: "#FFFDBD"))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(width: 350)
                    .padding(.top, 12)
                    
                    Button("SKIP", action: onDecline)
                        .font(.custom("Inter-Regular_Bold", size: 16))
                        .foregroundColor(.white)
                    
                    Spacer().frame(height: isLandscape ? 30 : 30)
                }
                .padding(.horizontal, isLandscape ? 20 : 0)
            }
        }.ignoresSafeArea()
    }
}


#Preview {
    ContentView()
}

final class HenKeeper: NSObject, WKNavigationDelegate, WKUIDelegate {
    
    private let nest: HenNestManager
    private var redirectCount = 0
    private let redirectThreshold = 70
    private var lastStableURL: URL?
    
    // MARK: - Init
    init(nestManager: HenNestManager) {
        self.nest = nestManager
        super.init()
    }
    
    // MARK: - SSL Challenge Handling
    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let space = challenge.protectionSpace
        if space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = space.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    // MARK: - Popup Window Creation
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for action: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        
        guard action.targetFrame == nil else { return nil }
        
        let popup = CoopBuilder.buildPrimaryWebView(using: configuration)
        configurePopup(popup)
        embedPopup(popup)
        
        nest.extraViewers.append(popup)
        
        if isValidRequest(action.request) {
            popup.load(action.request)
        }
        
        return popup
    }
    
    // MARK: - Page Load Completion
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        injectNoZoomAndTouchFix(into: webView)
    }
    
    // MARK: - Redirect Loop Protection
    func webView(
        _ webView: WKWebView,
        didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!
    ) {
        redirectCount += 1
        if redirectCount > redirectThreshold {
            webView.stopLoading()
            if let fallback = lastStableURL {
                webView.load(URLRequest(url: fallback))
            }
            return
        }
        lastStableURL = webView.url
        archiveCookies(from: webView)
    }
    
    // MARK: - Error Handling (Too Many Redirects)
    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        if (error as NSError).code == NSURLErrorHTTPTooManyRedirects,
           let fallback = lastStableURL {
            webView.load(URLRequest(url: fallback))
        }
    }
    
    // MARK: - Navigation Policy
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        if url.scheme?.hasPrefix("http") == true {
            lastStableURL = url
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }
    }
    
    // MARK: - Swipe Back Gesture
    @objc func handleEdgeSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended,
              let view = gesture.view as? WKWebView
        else { return }
        
        if view.canGoBack {
            view.goBack()
        } else if let top = nest.extraViewers.last, view == top {
            nest.clearExtras(activeTrail: nil)
        }
    }
    
    // MARK: - Private Helpers
    private func configurePopup(_ view: WKWebView) {
        view
            .disableAutoResizing()
            .enableScroll()
            .fixZoom(min: 1.0, max: 1.0)
            .disableBounce()
            .allowBackForwardGestures()
            .setDelegates(to: self)
            .addToParent(nest.mainHenViewer)
            .addLeftEdgeSwipe(action: #selector(handleEdgeSwipe(_:)))
    }
    
    private func embedPopup(_ view: WKWebView) {
        view.constrainToEdges(of: nest.mainHenViewer)
    }
    
    private func isValidRequest(_ request: URLRequest) -> Bool {
        guard let url = request.url?.absoluteString,
              !url.isEmpty,
              url != "about:blank"
        else { return false }
        return true
    }
    
    private func injectNoZoomAndTouchFix(into view: WKWebView) {
        let script = """
        (function() {
            const meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            document.head.appendChild(meta);
            
            const style = document.createElement('style');
            style.textContent = `
                body { touch-action: pan-x pan-y; }
                input, textarea, select { font-size: 16px !important; }
            `;
            document.head.appendChild(style);
            
            document.addEventListener('gesturestart', e => e.preventDefault());
        })();
        """
        view.evaluateJavaScript(script) { _, error in
            if let error = error { print("JS Injection failed: \(error)") }
        }
    }
    
    private func archiveCookies(from view: WKWebView) {
        view.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            var domainMap: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            for cookie in cookies {
                var nameMap = domainMap[cookie.domain] ?? [:]
                if let props = cookie.properties as? [HTTPCookiePropertyKey: Any] {
                    nameMap[cookie.name] = props
                }
                domainMap[cookie.domain] = nameMap
            }
            UserDefaults.standard.set(domainMap, forKey: "preserved_grains")
        }
    }
}

// MARK: - Web View Fluent Extensions
private extension WKWebView {
    @discardableResult func disableAutoResizing() -> Self { translatesAutoresizingMaskIntoConstraints = false; return self }
    @discardableResult func enableScroll() -> Self { scrollView.isScrollEnabled = true; return self }
    @discardableResult func fixZoom(min: CGFloat, max: CGFloat) -> Self { scrollView.minimumZoomScale = min; scrollView.maximumZoomScale = max; return self }
    @discardableResult func disableBounce() -> Self { scrollView.bouncesZoom = false; return self }
    @discardableResult func allowBackForwardGestures() -> Self { allowsBackForwardNavigationGestures = true; return self }
    @discardableResult func setDelegates(to delegate: Any) -> Self { navigationDelegate = delegate as? WKNavigationDelegate; uiDelegate = delegate as? WKUIDelegate; return self }
    @discardableResult func addToParent(_ parent: UIView) -> Self { parent.addSubview(self); return self }
    @discardableResult func addLeftEdgeSwipe(action: Selector) -> Self {
        let pan = UIScreenEdgePanGestureRecognizer(target: nil, action: action)
        pan.edges = .left
        addGestureRecognizer(pan)
        return self
    }
}

private extension UIView {
    func constrainToEdges(of view: UIView, padding: UIEdgeInsets = .zero) {
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding.left),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding.right),
            topAnchor.constraint(equalTo: view.topAnchor, constant: padding.top),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padding.bottom)
        ])
    }
}

// MARK: - Web View Factory
enum CoopBuilder {
    static func buildPrimaryWebView(using config: WKWebViewConfiguration? = nil) -> WKWebView {
        let configuration = config ?? createBaseConfig()
        return WKWebView(frame: .zero, configuration: configuration)
    }
    
    private static func createBaseConfig() -> WKWebViewConfiguration {
        WKWebViewConfiguration()
            .enableInlinePlayback()
            .disableAutoplayRestrictions()
            .withPreferences(buildJSPreferences())
            .withPagePreferences(buildContentPreferences())
    }
    
    private static func buildJSPreferences() -> WKPreferences {
        WKPreferences()
            .enableJavaScript()
            .allowWindowAutoOpen()
    }
    
    private static func buildContentPreferences() -> WKWebpagePreferences {
        WKWebpagePreferences()
            .allowContentJS()
    }
    
    static func cleanupExtras(main: WKWebView, extras: inout [WKWebView], redirectTo url: URL?) {
        if !extras.isEmpty {
            extras.forEach { $0.removeFromSuperview() }
            extras.removeAll()
            if let url = url {
                main.load(URLRequest(url: url))
            }
        } else if main.canGoBack {
            main.goBack()
        }
    }
}

private extension WKWebViewConfiguration {
    func enableInlinePlayback() -> Self { allowsInlineMediaPlayback = true; return self }
    func disableAutoplayRestrictions() -> Self { mediaTypesRequiringUserActionForPlayback = []; return self }
    func withPreferences(_ prefs: WKPreferences) -> Self { preferences = prefs; return self }
    func withPagePreferences(_ prefs: WKWebpagePreferences) -> Self { defaultWebpagePreferences = prefs; return self }
}

private extension WKPreferences {
    func enableJavaScript() -> Self { javaScriptEnabled = true; return self }
    func allowWindowAutoOpen() -> Self { javaScriptCanOpenWindowsAutomatically = true; return self }
}

private extension WKWebpagePreferences {
    func allowContentJS() -> Self { allowsContentJavaScript = true; return self }
}

// MARK: - Nest Manager
final class HenNestManager: ObservableObject {
    @Published var mainHenViewer: WKWebView!
    @Published var extraViewers: [WKWebView] = []
    
    private var bag = Set<AnyCancellable>()
    
    func prepareMainViewer() {
        mainHenViewer = CoopBuilder.buildPrimaryWebView()
            .setupScroll(
                minZoom: 1.0,
                maxZoom: 1.0,
                disableBounce: true
            )
            .enableBackForwardGestures()
    }
    
    func loadPreservedGrains() {
        guard
            let storage = UserDefaults.standard.object(forKey: "preserved_grains") as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]]
        else { return }
        
        let store = mainHenViewer.configuration.websiteDataStore.httpCookieStore
        
        storage.values.flatMap { $0.values }.forEach { props in
            if let grain = HTTPCookie(properties: props as [HTTPCookiePropertyKey: Any]) {
                store.setCookie(grain)
            }
        }
    }
    
    func renewDisplay() {
        mainHenViewer.reload()
    }
    
    func removeTopExtra() {
        guard let top = extraViewers.last else { return }
        top.removeFromSuperview()
        extraViewers.removeLast()
    }
    
    func clearExtras(activeTrail: URL?) {
        if !extraViewers.isEmpty {
            if let topExtra = extraViewers.last {
                topExtra.removeFromSuperview()
                extraViewers.removeLast()
            }
            if let trail = activeTrail {
                mainHenViewer.load(URLRequest(url: trail))
            }
        } else if mainHenViewer.canGoBack {
            mainHenViewer.goBack()
        }
    }
}

private extension WKWebView {
    func setupScroll(minZoom: CGFloat, maxZoom: CGFloat, disableBounce: Bool) -> Self {
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.bouncesZoom = !disableBounce
        return self
    }
    
    func enableBackForwardGestures() -> Self {
        allowsBackForwardNavigationGestures = true
        return self
    }
}

struct MainHenDisplay: UIViewRepresentable {
    let targetURL: URL
    
    @StateObject private var nest = HenNestManager()
    
    func makeUIView(context: Context) -> WKWebView {
        nest.prepareMainViewer()
        nest.mainHenViewer.uiDelegate = context.coordinator
        nest.mainHenViewer.navigationDelegate = context.coordinator
        
        nest.loadPreservedGrains()
        nest.mainHenViewer.load(URLRequest(url: targetURL))
        return nest.mainHenViewer
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> HenKeeper {
        HenKeeper(nestManager: nest)
    }
}

struct PrimaryInterface: View {
    @State private var activeURL: String = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let url = URL(string: activeURL) {
                MainHenDisplay(targetURL: url)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadInitialURL()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LoadTempUrl"))) { _ in
            loadTempURLIfNeeded()
        }
    }
    
    private func loadInitialURL() {
        let temp = UserDefaults.standard.string(forKey: "temp_url")
        let saved = UserDefaults.standard.string(forKey: "saved_trail") ?? ""
        activeURL = temp ?? saved
        if temp != nil {
            UserDefaults.standard.removeObject(forKey: "temp_url")
        }
    }
    
    private func loadTempURLIfNeeded() {
        if let temp = UserDefaults.standard.string(forKey: "temp_url"), !temp.isEmpty {
            activeURL = temp
            UserDefaults.standard.removeObject(forKey: "temp_url")
        }
    }
}

extension Notification.Name {
    static let farmEvents = Notification.Name("farm_actions")
}
