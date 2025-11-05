// PoultryFeedApp.swift
// Minimum iOS 14.0
import SwiftUI
import PDFKit
import Speech
import UserNotifications
import CoreImage.CIFilterBuiltins // For QR

@main
struct PoultryFeedApp: App {
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
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

#Preview {
    ContentView()
}

