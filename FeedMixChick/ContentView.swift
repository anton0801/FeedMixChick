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
                .buttonStyle(PremiumButtonStyle(background: .green))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // For tab bar
        }
    }
}

struct CalculatorView: View {
    @AppStorage("unit") private var globalUnit = "%"
    @AppStorage("currency") private var currency = "USD"
    @AppStorage("savedMixes") private var savedMixesData: Data = Data()
    
    @State private var birdType: BirdType = .chicken
    @State private var goal: Goal = .eggLaying
    @State private var age: AgeGroup = .adult
    @State private var weight: String = ""
    @State private var ingredients: [IngredientItem] = []
    @State private var showPicker = false
    @State private var unit = "%"
    
    @State private var totalPercentage: Double = 0
    @State private var calculatedNutrients: [String: Nutrient] = [:]
    @State private var recommendations: [String] = []
    @State private var costPerKg: Double = 0
    
    private var isComplete: Bool {
        unit == "%" ? abs(totalPercentage - 100) < 0.1 : !ingredients.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: "1E293B"),
                        Color(hex: "0F172A")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Прогресс-ринг
                        VStack(spacing: 16) {
                            Text("Feed Calculator")
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)
                            
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 12)
                                    .frame(width: 120, height: 120)
                                
                                Circle()
                                    .trim(from: 0, to: min(totalPercentage / 100, 1.0))
                                    .stroke(
                                        AngularGradient(colors: [.green, .mint], center: .center),
                                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 120, height: 120)
                                    .animation(.spring(response: 0.6), value: totalPercentage)
                                
                                VStack {
                                    Text("\(Int(totalPercentage))%")
                                        .font(.title.bold())
                                        .foregroundColor(.white)
                                    Text("Complete")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        .padding(.top)
                        
                        // Пикеры
                        HStack {
                            FancyPicker(title: "Bird", selection: $birdType, items: BirdType.allCases)
                            FancyPicker(title: "Goal", selection: $goal, items: Goal.allCases)
                        }
                        FancyPicker(title: "Age", selection: $age, items: AgeGroup.allCases)
                        
                        // Вес
                        TextField("Bird weight (kg)", text: $weight)
                            .keyboardType(.decimalPad)
                            .padding(16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        
                        // Режим
                        HStack {
                            Text("Unit").font(.headline).foregroundColor(.white)
                            Spacer()
                            Picker("", selection: $unit) {
                                Text("Percent %").tag("%")
                                Text("kg").tag("kg")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }
                        .padding(.horizontal)
                        
                        // Ингредиенты
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(ingredients) { item in
                                FancyIngredientCard(
                                    item: item,
                                    unit: unit,
                                    onDelete: {
                                        withAnimation {
                                            ingredients.removeAll { $0.id == item.id }
                                        }
                                    },
                                    onAmountChange: {
                                        calculateAll()
                                    }
                                )
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal)
                        .animation(.spring(), value: ingredients)
                        
                        // Рекомендации
                        if !recommendations.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Recommendations")
                                    .font(.title2.bold())
                                    .foregroundColor(.white)
                                ForEach(recommendations, id: \.self) { rec in
                                    Label(rec, systemImage: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                            .padding(.horizontal)
                        }
                        
                        // Стоимость
                        if costPerKg > 0 {
                            VStack(spacing: 8) {
                                Text("Cost per kg")
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.8))
                                Text("\(costPerKg, specifier: "%.2f") \(currency)")
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                            .padding(.horizontal)
                        }
                        
                        // Кнопки
                        HStack(spacing: 16) {
                            Button("Auto Fill") {
                                autoSuggest()
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                            
                            Button("Save Mix") {
                                saveMix()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(isComplete ? .green : .gray)
                            .disabled(!isComplete)
                            .scaleEffect(isComplete ? 1.05 : 1.0)
                            .animation(.spring(), value: isComplete)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
                
                // Плавающая кнопка +
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showPicker = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 70, height: 70)
                                .background(Circle().fill(.green).shadow(radius: 10))
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $alertShow, content: {
                Alert(title: Text("Alert"), message: Text(alertMessage))
            })
            .onAppear { unit = globalUnit }
            .onChange(of: ingredients) { _ in calculateAll() }
            .onChange(of: unit) { _ in calculateAll() }
            .sheet(isPresented: $showPicker) {
                IngredientPicker { ingredient in
                    withAnimation {
                        ingredients.append(IngredientItem(ingredient: ingredient))
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func calculateAll() {
        totalPercentage = unit == "%" ? ingredients.reduce(0) { $0 + $1.amount } : 0
        calculateNutrients()
        calculateCost()
    }
    
    private func calculateNutrients() {
        var totals: [String: Double] = [:]
        var totalWeight: Double = 0
        
        for item in ingredients {
            let weight = unit == "%" ? item.amount / 100 : item.amount
            totalWeight += weight
            for (key, nut) in item.ingredient.nutrients {
                totals[key, default: 0] += nut.value * weight
            }
        }
        
        guard totalWeight > 0 else { calculatedNutrients = [:]; return }
        
        var result: [String: Nutrient] = [:]
        for (key, total) in totals {
            let value = key == "Energy" ? total : (total / totalWeight) * 100
            result[key] = Nutrient(name: key, value: value, unit: key == "Energy" ? "kcal/kg" : "%")
        }
        calculatedNutrients = result
        checkRecommendations()
    }
    
    private func checkRecommendations() {
        recommendations.removeAll()
        guard let norms = nutrientNorms[birdType]?[goal]?[age] else { return }
        for (key, range) in norms {
            if let val = calculatedNutrients[key]?.value {
                if val < range.min { recommendations.append("Low \(key): add more sources") }
                if val > range.max { recommendations.append("High \(key): reduce") }
            }
        }
    }
    
    private func calculateCost() {
        let totalCost = ingredients.reduce(0) {
            let amount = unit == "%" ? $1.amount / 100 : $1.amount
            return $0 + amount * ($1.ingredient.pricePerKg ?? 0)
        }
        let totalWeight = unit == "%" ? 1.0 : ingredients.reduce(0) { $0 + $1.amount }
        costPerKg = totalWeight > 0 ? totalCost / totalWeight : 0
    }
    
    private func autoSuggest() {
        guard let proteinNorm = nutrientNorms[birdType]?[goal]?[age]?["Protein"]?.min,
              let current = calculatedNutrients["Protein"]?.value,
              current < proteinNorm,
              let soy = defaultIngredients.first(where: { $0.name.localizedCaseInsensitiveContains("soy") }) else { return }
        
        if !ingredients.contains(where: { $0.ingredient.id == soy.id }) {
            withAnimation {
                ingredients.append(IngredientItem(ingredient: soy, amount: 18))
            }
        }
    }
    
    private func saveMix() {
        let mix = FeedMix(
            name: "Mix • \(Date().formatted(.dateTime.weekday().month().day().hour().minute()))",
            birdType: birdType,
            goal: goal,
            age: age,
            weight: Double(weight) ?? 0,
            ingredients: ingredients.map { IngredientAmount(ingredient: $0.ingredient, amount: $0.amount, unit: unit) },
            calculatedNutrients: calculatedNutrients,
            date: Date(),
            costPerKg: costPerKg,
        )
        var mixes = (try? JSONDecoder().decode([FeedMix].self, from: savedMixesData)) ?? []
        mixes.append(mix)
        savedMixesData = (try? JSONEncoder().encode(mixes)) ?? Data()
        alertShow = true
        alertMessage = "Feed Added"
        withAnimation {
            ingredients = []
            calculatedNutrients = [:]
            costPerKg = 0.0
            weight = ""
            calculateAll()
        }
    }
    
    @State var alertShow = false
    @State var alertMessage = ""
    
}

// MARK: - КОМПОНЕНТЫ (все ошибки исправлены)
struct FancyPicker<T: CaseIterable & RawRepresentable & Hashable>: View where T.RawValue == String, T: Identifiable {
    let title: String
    @Binding var selection: T
    let items: T.AllCases
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundColor(.white.opacity(0.8))
            Picker(title, selection: $selection) {
                ForEach(Array(items), id: \.self) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.menu)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}

struct FancyIngredientCard: View {
    @ObservedObject var item: IngredientItem
    let unit: String
    let onDelete: () -> Void
    let onAmountChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill").foregroundColor(.green)
                Text(item.ingredient.name)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundColor(.red)
                }
            }
            
            HStack {
                if unit == "%" {
                    Slider(value: $item.amount, in: 0...100, step: 0.5)
                        .tint(.green)
                        .onChange(of: item.amount) { _ in onAmountChange() }
                } else {
                    TextField("0", value: $item.amount, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                Text(unit)
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Text("\(item.amount, specifier: "%.1f") \(unit)")
                .font(.title2.bold())
                .foregroundColor(.white)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 8)
    }
}

struct IngredientPicker: View {
    let onSelect: (Ingredient) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var search = ""
    
    var filtered: [Ingredient] {
        search.isEmpty ? defaultIngredients : defaultIngredients.filter {
            $0.name.localizedCaseInsensitiveContains(search)
        }
    }
    
    var body: some View {
        NavigationView {
            List(filtered) { ing in
                Button {
                    onSelect(ing)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text(ing.name)
                            .font(.title3.bold())
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Add Ingredient")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct PremiumButtonStyle: ButtonStyle {
    let background: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(background.opacity(configuration.isPressed ? 0.8 : 1))
            .cornerRadius(16)
            .shadow(radius: 5)
    }
}

struct IngredientCardView: View {
    @Binding var item: IngredientItem
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                Text(item.ingredient.name)
                    .font(.headline)
                Spacer()
            }
            
            HStack {
                if unit == "%" {
                    Slider(value: $item.amount, in: 0...100, step: 0.5)
                        .tint(.green)
                } else {
                    TextField("0", value: $item.amount, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
                Text(unit)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            
            Text("\(item.amount, specifier: "%.1f") \(unit)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.green.opacity(0.3), lineWidth: 1))
    }
}

struct NutrientsCard: View {
    let nutrients: [String: Nutrient]
    let birdType: BirdType
    let goal: Goal
    let age: AgeGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrients")
                .font(.title2.bold())
            
            ForEach(nutrients.keys.sorted(), id: \.self) { key in
                if let nut = nutrients[key] {
                    let color = getColor(for: nut, key: key, birdType: birdType, goal: goal, age: age)
                    HStack {
                        Text("\(key):")
                        Spacer()
                        Text("\(nut.value, specifier: "%.2f") \(nut.unit)")
                            .foregroundColor(color)
                            .bold()
                    }
                    Divider()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(20)
        .padding(.horizontal)
    }
    
    private func getColor(for nutrient: Nutrient, key: String, birdType: BirdType, goal: Goal, age: AgeGroup) -> Color {
        guard let range = nutrientNorms[birdType]?[goal]?[age]?[key] else { return .primary }
        let val = nutrient.value
        if val >= range.min && val <= range.max { return .green }
        if val < range.min { return .orange }
        return .red
    }
}

struct RecommendationsCard: View {
    let recommendations: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.title2.bold())
            ForEach(recommendations, id: \.self) { rec in
                Label(rec, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(20)
        .padding(.horizontal)
    }
}

struct IngredientPickerView: View {
    let onSelect: (Ingredient) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var search = ""
    
    var filtered: [Ingredient] {
        search.isEmpty ? defaultIngredients : defaultIngredients.filter {
            $0.name.lowercased().contains(search.lowercased())
        }
    }
    
    var body: some View {
        NavigationView {
            List(filtered) { ing in
                Button {
                    onSelect(ing)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text(ing.name)
                            .font(.headline)
                    }
                }
            }
            .searchable(text: $search)
            .navigationTitle("Add Ingredient")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

func premiumPicker<T: CaseIterable & RawRepresentable & Hashable>(
    title: String,
    selection: Binding<T>,
    items: T.AllCases
) -> some View where T.RawValue == String {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal)
        
        Picker(title, selection: selection) {
            ForEach(Array(items), id: \.self) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.menu)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Класс-интгредиент (главное!)
class IngredientItem: Identifiable, ObservableObject, Equatable {
    let id = UUID()
    let ingredient: Ingredient
    @Published var amount: Double = 0
    
    init(ingredient: Ingredient, amount: Double = 0) {
        self.ingredient = ingredient
        self.amount = amount
    }
    
    static func == (lhs: IngredientItem, rhs: IngredientItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct PremiumActionButton: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(18)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: color.opacity(0.4), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
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
//            .toolbar {
//                Button("Add Custom") { showAddCustom = true }
//            }
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
                .buttonStyle(PremiumButtonStyle(background: .green))
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
            
            Section(header: Text("Privacy & Support").font(Font.premiumCaption).foregroundColor(Color.grainBrown)) {
                Button {
                    UIApplication.shared.open(URL(string: "https://feedmiix.com/privacy-policy.html")!)
                } label: {
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                Button {
                    UIApplication.shared.open(URL(string: "https://feedmiix.com/support.html")!)
                } label: {
                    HStack {
                        Text("Support Form")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
            }
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
    
    enum StateType {
        case loading
        case henView
        case fallback
        case offline
    }
    
    init() {
        subscribeToConversionData()
        monitorNetworkReachability()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func subscribeToConversionData() {
        NotificationCenter.default
            .publisher(for: Notification.Name("ConversionDataReceived"))
            .compactMap { $0.userInfo?["conversionData"] as? [AnyHashable: Any] }
            .sink { [weak self] data in
                self?.attribInfo = data
                print("[AFSDK] data \(data)")
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
            if !UserDefaults.standard.bool(forKey: "accepted_notifications") && !UserDefaults.standard.bool(forKey: "system_close_notifications") {
                shouldShowNotificationPrompt()
            } else {
                initiateConfigurationCall()
            }
        }
    }
    
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
        transition(to: .offline)
//        let mode = UserDefaults.standard.string(forKey: "app_mode")
//        mode == "HenView" ? transition(to: .offline) : activateFallbackMode()
    }
    
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
        
        var merged = json
        
        for (key, value) in deeplinkValues {
            if merged[key] == nil {
                merged[key] = value
            }
        }
        
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
    
    private func fallbackOnMissingConfig() {
        if let saved = UserDefaults.standard.string(forKey: "saved_trail"),
           let url = URL(string: saved) {
            if currentState == .offline {
                currentState = .offline
            } else {
                contentTrail = url
                currentState = .henView
            }
        } else {
            activateFallbackMode()
        }
    }
    
    private func activateFallbackMode() {
        UserDefaults.standard.set("Funtik", forKey: "app_mode")
        UserDefaults.standard.set(true, forKey: "hasLaunched")
        transition(to: .fallback)
    }
    
    private func shouldShowNotificationPrompt() {
        if let lastCheck = UserDefaults.standard.value(forKey: "last_notification_ask") as? Date,
           Date().timeIntervalSince(lastCheck) < 259200 {
            initiateConfigurationCall()
            return
        }
        displayPrompt()
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

struct LaunchScreen: View {
    @StateObject private var flow = FarmStarter()
    
    @State var isLandscape: Bool = false
    
    var body: some View {
        ZStack {
            if flow.currentState == .loading || flow.showPermissionPrompt {
                LoadingScreen(isLandscape: $isLandscape)
            }
            
            if flow.showPermissionPrompt {
                
            } else {
                primaryContent
            }
        }
        .fullScreenCover(isPresented: $flow.showPermissionPrompt) {
            PermissionPrompt(
                onAccept: flow.requestPermission,
                onDecline: flow.dismissPrompt,
                isLandscape: $isLandscape
            )
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
            OfflineScreen(isLandscape: $isLandscape)
        }
    }
}


struct LoadingScreen: View {
    
    @Binding var isLandscape: Bool
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image("feedmix_bg_splash")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                    .frame(maxWidth: geo.size.width,
                           maxHeight: geo.size.height)
            }
            Image("logo")
                .resizable()
                .scaledToFill()
                .frame(width: 300, height: 300)
            
            VStack {
                Spacer()
                Text("LOADING...")
                    .font(.custom("Flipbash", size: 26))
                    .foregroundColor(.white)
                    .shadow(color: Color(hex: "#456CE1"), radius: 1, x: -1, y: 0)
                    .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 1, y: 0)
                    .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 0, y: 1)
                    .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 0, y: -1)
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 280, height: 8)
                    
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(hex: "#456CE1"), Color(hex: "#456CE1")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: 90, height: 8)
                        .offset(x: isAnimating ? 200 : -20)
                }
                .padding(.horizontal)
                .onAppear {
                    withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
                
                Spacer().frame(height: 80)
            }
        }
        .ignoresSafeArea()
    }
}

struct OfflineScreen: View {
    @Binding var isLandscape: Bool
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image("feedmix_bg_splash")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                    .frame(maxWidth: geo.size.width,
                           maxHeight: geo.size.height)
            }
            Image("logo")
                .resizable()
                .scaledToFill()
                .frame(width: 300, height: 300)
            
            VStack {
                Image("internet_check")
                    .resizable()
                    .frame(width: 300, height: 250)
                    .padding(.top, 62)
            }
        }.ignoresSafeArea()
    }
}

struct PermissionPrompt: View {
    @Environment(\.dismiss) var dismiss
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @Binding var isLandscape: Bool
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image("feedmix_bg_splash")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                    .frame(maxWidth: geo.size.width,
                           maxHeight: geo.size.height)
            }
            Image("logo")
                .resizable()
                .scaledToFill()
                .frame(width: 300, height: 300)
            
            VStack(spacing: 8) {
                Spacer()
                Text("Allow notifications about bonuses and promos".uppercased())
                    .font(.custom("Flipbash", size: 18))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                Text("Stay tuned with best offers from our casino")
                    .font(.custom("Flipbash", size: 15))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 52)
                    .padding(.top, 4)
                
                Button(action: {
                    onAccept()
                }) {
                    Image("want_btn")
                        .resizable()
                        .frame(height: 60)
                }
                .frame(width: 350)
                .padding(.top, 12)
                
                Button("SKIP", action: {
                    dismiss()
                    onDecline()
                })
                    .font(.custom("Flipbash", size: 16))
                    .foregroundColor(.white)
                    .shadow(color: Color(hex: "#456CE1"), radius: 1, x: -1, y: 0)
                    .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 1, y: 0)
                    .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 0, y: 1)
                    .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 0, y: -1)
                
                Spacer().frame(height: 20)
            }
        }
    }
}


#Preview {
    PermissionPrompt(onAccept: {
        
    }, onDecline: {
        
    }, isLandscape: .constant(false))
}

final class HnKMixeper: NSObject, WKNavigationDelegate, WKUIDelegate {
    
    private let nest: HenNestManager
    private var redirectCount = 0
    private let redirectThreshold = 70
    private var lastStableURL: URL?
    
    init(nestManager: HenNestManager) {
        self.nest = nestManager
        super.init()
    }
    
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
        
        nest.extraMOringViewers.append(popup)
        
        let swipeGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(processSwipe(_:)))
        swipeGesture.edges = .left
        popup.addGestureRecognizer(swipeGesture)
        
        if isValidRequest(action.request) {
            popup.load(action.request)
        }
        
        return popup
    }
    
    
    @objc func processSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .ended {
            guard let view = gesture.view as? WKWebView else { return }
            if view.canGoBack {
                view.goBack()
            } else if let topExtra = nest.extraMOringViewers.last, view == topExtra {
                nest.clearExtras(activeTrail: nil)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let lockScript = """
        var viewportMeta = document.createElement('meta');
        viewportMeta.name = 'viewport';
        viewportMeta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
        document.head.appendChild(viewportMeta);
        var lockStyle = document.createElement('style');
        lockStyle.innerText = 'body { touch-action: pan-x pan-y; } input, textarea, select { font-size: 16px !important; maximum-scale=1.0; }';
        document.head.appendChild(lockStyle);
        document.addEventListener('gesturestart', e => e.preventDefault());
        """;
        webView.evaluateJavaScript(lockScript) { _, fail in
            if let fail = fail {
                print("Lock injection failed: \(fail)")
            }
        }
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
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
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url {
            lastStableURL = url
            
            if url.scheme?.hasPrefix("http") != true {
                print("open url \(url)")
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
    
    @objc func handleEdgeSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended,
              let view = gesture.view as? WKWebView
        else { return }
        
        if view.canGoBack {
            view.goBack()
        } else if let top = nest.extraMOringViewers.last, view == top {
            nest.clearExtras(activeTrail: nil)
        }
    }
    
    private func configurePopup(_ view: WKWebView) {
        view
            .disableAutoResizing()
            .enableScroll()
            .fixZoom(min: 1.0, max: 1.0)
            .disableBounce()
            .allowBackForwardGestures()
            .setDelegates(to: self)
            .addToParent(nest.nestAppsda)
    }
    
    private func embedPopup(_ view: WKWebView) {
        view.constrainToEdges(of: nest.nestAppsda)
    }
    
    private func isValidRequest(_ request: URLRequest) -> Bool {
        guard let url = request.url?.absoluteString,
              !url.isEmpty,
              url != "about:blank"
        else { return false }
        return true
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
        let w = WKWebView(frame: .zero, configuration: configuration)

        return w
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
    @Published var nestAppsda: WKWebView!
    @Published var extraMOringViewers: [WKWebView] = []
    
    private var bag = Set<AnyCancellable>()
    
    func prepareMainViewer() {
        nestAppsda = CoopBuilder.buildPrimaryWebView()
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
        
        let store = nestAppsda.configuration.websiteDataStore.httpCookieStore
        
        storage.values.flatMap { $0.values }.forEach { props in
            if let grain = HTTPCookie(properties: props as [HTTPCookiePropertyKey: Any]) {
                store.setCookie(grain)
            }
        }
    }
    
    func renewDisplay() {
        nestAppsda.reload()
    }
    
    func removeTopExtra() {
        guard let top = extraMOringViewers.last else { return }
        top.removeFromSuperview()
        extraMOringViewers.removeLast()
    }
    
    func clearExtras(activeTrail: URL?) {
        if !extraMOringViewers.isEmpty {
            if let topExtra = extraMOringViewers.last {
                topExtra.removeFromSuperview()
                extraMOringViewers.removeLast()
            }
            if let trail = activeTrail {
                nestAppsda.load(URLRequest(url: trail))
            }
        } else if nestAppsda.canGoBack {
            nestAppsda.goBack()
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
        nest.nestAppsda.uiDelegate = context.coordinator
        nest.nestAppsda.navigationDelegate = context.coordinator
        
        nest.loadPreservedGrains()
        nest.nestAppsda.load(URLRequest(url: targetURL))
        return nest.nestAppsda
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> HnKMixeper {
        HnKMixeper(nestManager: nest)
    }
}

struct PrimaryInterface: View {
    @State private var activeURL: String = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let url = URL(string: activeURL) {
                MainHenDisplay(targetURL: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
