//
//  ContentView.swift
//  Harr KC's Hall
//
//


// RatsColony: SwiftUI + SpriteKit prototype
// iOS 16.0+, Swift 5.9+
// Single-file drop-in for quick testing. Split by // --- File: ... sections if you prefer.
// Notes:
// - Uses SpriteKit for the field (left house+hunter, right burrows and rats running in).
// - The simulation follows the 5 phases you described; visuals are a lightweight "cinematic" of Phase 2 + a brief "inside" banner.
// - Replace placeholder image names with your actual assets (see bottom of file for suggestions).

import SwiftUI
import SpriteKit

// --- MARK: - Utilities

@inlinable func clamp<T: Comparable>(_ x: T, _ a: T, _ b: T) -> T { max(a, min(b, x)) }

extension Int {
    static func binomial(_ n: Int, p: Double) -> Int {
        guard n > 0 else { return 0 }
        let p = clamp(p, 0.0, 1.0)
        var c = 0
        if p <= 0 { return 0 }
        if p >= 1 { return n }
        for _ in 0..<n { if Double.random(in: 0...1) < p { c += 1 } }
        return c
    }
}

// --- MARK: - Game Domain Models

enum MissionPlan: String, CaseIterable, Identifiable {
    case vulnerability = "Поиск уязвимости"
    case passage = "Создание прохода"
    var id: String { rawValue }
}

final class Burrow: Identifiable, ObservableObject {
    let id = UUID()
    @Published var name: String
    @Published var level: Int // 1..5 affects survival & loot
    @Published var capacity: Int
    @Published var rats: Int // current population
    init(name: String, level: Int = 1, capacity: Int = 6, rats: Int = 6) {
        self.name = name
        self.level = level
        self.capacity = capacity
        self.rats = min(rats, capacity)
    }
    var lootCoef: Double { 1.0 + 0.5 * Double(level - 1) } // 1.0, 1.5, 2.0, 2.5, 3.0
    var skillBonus: Double { 0.012 * Double(level) } // reduces risks a bit
    var upgradeCost: Int { 60 * level } // simple scale: 60,120,180,240
    var canUpgrade: Bool { level < 5 }
}

struct MissionOrder {
    var selection: [UUID: Int] = [:] // burrowID -> squad size
    var totalSelected: Int { selection.values.reduce(0, +) }
}

struct MissionOutcome {
    var sent: Int
    var fieldLost: Int
    var insideLost: Int
    var returned: Int
    var loot: Int
    var wearDelta: Double
    var successNote: String
}

// --- MARK: - Game State & Simulation

@MainActor
final class GameState: ObservableObject {
    // Colony & house
    @Published var supplies: Int = 100
    @Published var houseWear: Double = 0.0 // 0..100 (win at 100)
    @Published var houseLevel: Int = 2 // 1..10 increases difficulty
    @Published var totalRatsKilled: Int = 0
    @Published var wave: Int = 1

    @Published var burrows: [Burrow] = [
        Burrow(name: "Нора A", level: 1, capacity: 6, rats: 6),
        Burrow(name: "Нора B", level: 1, capacity: 8, rats: 8)
    ]

    // UI selection
    @Published var plan: MissionPlan = .vulnerability
    @Published var order = MissionOrder()

    // Scene bridge
    weak var scene: FieldScene?

    var totalRats: Int { burrows.map{ $0.rats }.reduce(0,+) }

    func resetSelection() { order = MissionOrder() }

    // --- Upgrades & Economy
    func recruitRats(in burrow: Burrow, amount: Int) {
        guard amount > 0 else { return }
        let free = max(0, burrow.capacity - burrow.rats)
        let add = min(amount, free, supplies) // 1 supply -> 1 rat
        burrow.rats += add
        supplies -= add
    }

    func upgrade(burrow: Burrow) {
        guard burrow.canUpgrade, supplies >= burrow.upgradeCost else { return }
        supplies -= burrow.upgradeCost
        burrow.level += 1
        burrow.capacity += 3
    }

    func createBurrow() {
        guard supplies >= 120 else { return }
        supplies -= 120
        burrows.append(Burrow(name: "Нора \(burrows.count + 1)", level: 1, capacity: 6, rats: 0))
    }

    func weakenHouse() {
        guard supplies >= 100 else { return }
        supplies -= 100
        houseLevel = max(1, houseLevel - 1)
        houseWear = min(100, houseWear + 5)
    }

    // --- Core simulation (Phases 1-4)
    func runMission() {
        let totalToSend = order.totalSelected
        guard totalToSend > 0 else { return }

        // Phase 1: assemble squads, reserve rats
        var squads: [(burrow: Burrow, count: Int)] = []
        for (id, cnt) in order.selection {
            if let b = burrows.first(where: { $0.id == id }), cnt > 0, b.rats >= cnt {
                b.rats -= cnt
                squads.append((b, cnt))
            }
        }
        guard !squads.isEmpty else { return }

        // Aggregate for visuals per-burrow
        var visualPlans: [UUID: (sent: Int, fieldLost: Int, insideLost: Int, returned: Int)] = [:]

        // Resolve each squad independently, accumulate results
        var totalOutcome = MissionOutcome(sent: 0, fieldLost: 0, insideLost: 0, returned: 0, loot: 0, wearDelta: 0, successNote: "")

        // Determine mission pre-checks per plan
        func checkVulnerabilityChance() -> (success: Bool, note: String, riskMult: Double, insideBonus: Double) {
            let chance = clamp(0.6 - 0.05 * Double(houseLevel), 0.1, 0.7)
            let ok = Double.random(in: 0...1) < chance
            return (ok, ok ? "Найдена щель" : "Щель не найдена", ok ? 0.7 : 1.0, ok ? 0.08 : 0.0)
        }
        func checkPassageChance(avgLevel: Double) -> (success: Bool, note: String, riskMult: Double, insideBonus: Double, wearBonus: Double) {
            let chance = clamp(0.3 + 0.08 * avgLevel, 0.15, 0.85)
            let ok = Double.random(in: 0...1) < chance
            return (ok, ok ? "Прогрызли ход" : "Ход не удался", ok ? 0.5 : 1.1, ok ? 0.12 : -0.05, ok ? 2.0 : 0.0)
        }

        let avgLevel = squads.map{ Double($0.burrow.level) }.reduce(0,+) / Double(max(1, squads.count))

        var planNote = ""
        var riskMult = 1.0
        var insideBonus = 0.0
        var wearBonus = 0.0

        switch plan {
        case .vulnerability:
            let r = checkVulnerabilityChance()
            planNote = r.note
            riskMult = r.riskMult
            insideBonus = r.insideBonus
        case .passage:
            let r = checkPassageChance(avgLevel: avgLevel)
            planNote = r.note
            riskMult = r.riskMult
            insideBonus = r.insideBonus
            wearBonus = r.wearBonus
        }

        for (burrow, count) in squads {
            let one = resolveSquad(from: burrow, count: count, riskMult: riskMult, insideBonus: insideBonus)
            totalOutcome.sent += one.sent
            totalOutcome.fieldLost += one.fieldLost
            totalOutcome.insideLost += one.insideLost
            totalOutcome.returned += one.returned
            totalOutcome.loot += one.loot
            totalOutcome.wearDelta += one.wearDelta
            visualPlans[burrow.id] = (sent: one.sent, fieldLost: one.fieldLost, insideLost: one.insideLost, returned: one.returned)
        }

        totalOutcome.wearDelta += wearBonus
        totalOutcome.successNote = planNote

        // Phase 4: apply
        supplies += totalOutcome.loot
        houseWear = clamp(houseWear + totalOutcome.wearDelta, 0, 100)
        totalRatsKilled += totalOutcome.fieldLost + totalOutcome.insideLost
        // Return survivors to their originating burrows proportionally
        for (burrow, count) in squads {
            let vp = visualPlans[burrow.id]!
            burrow.rats += vp.returned
        }
        wave += 1

        // Phase 2 cinematic -> Scene
        scene?.playMissionCinematic(visual: visualPlans, note: totalOutcome.successNote, loot: totalOutcome.loot)

        // Clear UI selection
        resetSelection()
    }

    private func resolveSquad(from burrow: Burrow, count: Int, riskMult: Double, insideBonus: Double) -> MissionOutcome {
        // Field (Phase 2) risks depend on house level, prior kills, burrow level
        let killsFactor = 0.0007 * Double(totalRatsKilled)
        var trapP = clamp(0.05 + 0.02 * Double(houseLevel) + killsFactor - burrow.skillBonus, 0.02, 0.8) * riskMult
        var hunterP = clamp(0.05 + 0.03 * Double(houseLevel) + 1.2 * killsFactor - 1.1 * burrow.skillBonus, 0.02, 0.9) * riskMult
        // crowd pressure: large squads draw more attention
        let crowd = clamp(0.004 * Double(count), 0.0, 0.15)
        trapP = clamp(trapP + crowd * 0.4, 0.0, 0.95)
        hunterP = clamp(hunterP + crowd * 0.6, 0.0, 0.95)

        // Independent risks -> combined per-rat elimination probability
        let pElimField = 1.0 - (1.0 - trapP) * (1.0 - hunterP)
        let fieldLost = Int.binomial(count, p: pElimField)
        let toHouse = max(0, count - fieldLost)

        // Inside (Phase 3) survival
        var insideSurviveP = clamp(0.75 - 0.05 * Double(houseLevel) - 0.0005 * Double(totalRatsKilled) - 0.02 * Double(wave / 5) + 0.03 * Double(burrow.level) + insideBonus, 0.05, 0.95)
        let insideSurvivors = Int.binomial(toHouse, p: insideSurviveP)
        let insideLost = toHouse - insideSurvivors

        // Loot
        let loot = Int( Double(insideSurvivors) * burrow.lootCoef )

        // Wear increase is driven by survivors touching structure and pressure of the attack
        let wearDelta = Double(toHouse) * 0.15 + Double(insideSurvivors) * 0.2

        return MissionOutcome(
            sent: count,
            fieldLost: fieldLost,
            insideLost: insideLost,
            returned: insideSurvivors,
            loot: loot,
            wearDelta: wearDelta,
            successNote: ""
        )
    }
}

// --- MARK: - SpriteKit Scene

final class FieldScene: SKScene {
    weak var game: GameState?

    // Nodes
    private var house: SKSpriteNode!
    private var hunter: SKSpriteNode!
    private var ground: SKSpriteNode!

    // Layout helpers
    private var leftX: CGFloat { size.width * 0.18 }
    private var rightX: CGFloat { size.width * 0.82 }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        build()
    }

    private func build() {
        removeAllChildren()

        // Ground / field backdrop (isometric hint via skewed texture optional)
        ground = SKSpriteNode(color: SKColor(white: 0.12, alpha: 1), size: CGSize(width: size.width * 0.92, height: size.height * 0.7))
        ground.position = CGPoint(x: size.width * 0.5, y: size.height * 0.45)
        ground.zPosition = -10
        addChild(ground)

        // House on the left
        house = SKSpriteNode(imageNamed: "house")
        if house.texture == nil { // fallback rectangle if asset missing
            house = SKSpriteNode(color: .brown, size: CGSize(width: 120, height: 120))
        } else { house.size = CGSize(width: 140, height: 140) }
        house.position = CGPoint(x: leftX, y: size.height * 0.55)
        house.zPosition = 10
        addChild(house)

        // Hunter slightly below
        hunter = SKSpriteNode(imageNamed: "hunter")
        if hunter.texture == nil { hunter = SKSpriteNode(color: .red, size: CGSize(width: 72, height: 72)) }
        else { hunter.size = CGSize(width: 90, height: 90) }
        hunter.position = CGPoint(x: leftX + 40, y: size.height * 0.35)
        hunter.zPosition = 11
        addChild(hunter)

        // Decorative: faint stripes to hint at iso depth
        for i in 0..<6 {
            let line = SKShapeNode(rectOf: CGSize(width: ground.size.width * 0.85, height: 2), cornerRadius: 1)
            line.fillColor = SKColor(white: 1, alpha: 0.08)
            line.strokeColor = .clear
            line.position = CGPoint(x: size.width * 0.5, y: ground.position.y - ground.size.height*0.4 + CGFloat(i) * ground.size.height/6)
            line.zPosition = -5
            addChild(line)
        }
    }

    override func didChangeSize(_ oldSize: CGSize) { build() }

    // Simple bullet flash from hunter to a target
    private func fire(at target: SKNode) {
        let shot = SKShapeNode(circleOfRadius: 4)
        shot.fillColor = .white
        shot.strokeColor = .clear
        shot.position = hunter.position
        shot.zPosition = 12
        addChild(shot)
        let move = SKAction.move(to: target.position, duration: 0.2)
        let fade = SKAction.fadeOut(withDuration: 0.05)
        shot.run(.sequence([move, fade, .removeFromParent()]))
    }

    // Public: run a cinematic pass showing rats running in and getting picked off
    func playMissionCinematic(visual: [UUID: (sent: Int, fieldLost: Int, insideLost: Int, returned: Int)], note: String, loot: Int) {
        // Spawn waves per-burrow in rows from right to left
        let burrowIDs = Array(visual.keys)
        let rowCount = max(1, burrowIDs.count)
        var globalDelay: TimeInterval = 0.0

        for (idx, id) in burrowIDs.enumerated() {
            let v = visual[id]!
            guard v.sent > 0 else { continue }
            let rowY = size.height * (0.25 + 0.5 * (CGFloat(idx + 1) / CGFloat(rowCount + 1)))
            let pathStart = CGPoint(x: rightX, y: rowY)
            let pathEnd = CGPoint(x: leftX + 20, y: rowY + 20)

            let casualtiesField = v.fieldLost
            let casualtiesInside = v.insideLost
            let survivors = v.returned

            // For visuals, spawn exactly v.sent rats. Remove `casualtiesField` along the path, then `casualtiesInside` at the house.
            for i in 0..<v.sent {
                let rat = makeRat()
                rat.position = pathStart
                rat.zPosition = 6
                addChild(rat)

                let travelT: TimeInterval = 2.0 + TimeInterval(Double.random(in: 0.0...0.6))
                let delay = 0.05 * Double(i) + globalDelay
                var actions: [SKAction] = [ .wait(forDuration: delay) ]

                // Decide this rat's fate for visuals
                let fate: String
                if i < casualtiesField { fate = "field" }
                else if i < casualtiesField + casualtiesInside { fate = "inside" }
                else if i < casualtiesField + casualtiesInside + survivors { fate = "survive" }
                else { fate = "field" } // safety

                let move = SKAction.move(to: pathEnd, duration: travelT)
                move.timingMode = .easeIn

                if fate == "field" {
                    // Midway removal + hunter shot
                    let midpoint = CGPoint(x: (pathStart.x + pathEnd.x)/2, y: (pathStart.y + pathEnd.y)/2 + CGFloat.random(in: -20...20))
                    let moveHalf = SKAction.move(to: midpoint, duration: travelT * 0.5)
                    let vanish = SKAction.run { [weak self, weak rat] in
                        if let r = rat { self?.fire(at: r) }
                        rat?.run(.sequence([.fadeOut(withDuration: 0.1), .removeFromParent()]))
                    }
                    actions += [ moveHalf, vanish ]
                } else if fate == "inside" {
                    // Reach the house then disappear quickly
                    let fade = SKAction.run { [weak self, weak rat] in
                        self?.fire(at: rat ?? self!.house)
                    }
                    let vanish = SKAction.sequence([.wait(forDuration: 0.05), .fadeOut(withDuration: 0.15), .removeFromParent()])
                    actions += [ move, fade, vanish ]
                } else {
                    // Survive: reach and wait near house, then run off behind it
                    let pause = SKAction.wait(forDuration: 0.3)
                    let hide = SKAction.fadeOut(withDuration: 0.3)
                    actions += [ move, pause, hide, .removeFromParent() ]
                }

                rat.run(.sequence(actions))
            }

            globalDelay += 0.15 * Double(v.sent)
        }

        // Info banners
        showBanner(text: note, color: .systemYellow)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            self?.showBanner(text: "+\(loot) припасов", color: .systemGreen)
        }
    }

    private func makeRat() -> SKSpriteNode {
        var node = SKSpriteNode(imageNamed: "rat")
        if node.texture == nil { node = SKSpriteNode(color: .gray, size: CGSize(width: 28, height: 18)) }
        else { node.size = CGSize(width: 34, height: 22) }
        node.alpha = 0.95
        node.setScale(1.0)
        return node
    }

    private func showBanner(text: String, color: UIColor) {
        guard !text.isEmpty else { return }
        let bg = SKShapeNode(rectOf: CGSize(width: size.width * 0.6, height: 44), cornerRadius: 12)
        bg.fillColor = SKColor(cgColor: color.cgColor)
        bg.alpha = 0.85
        bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width/2, y: size.height * 0.85)
        bg.zPosition = 100

        let label = SKLabelNode(text: text)
        label.fontName = "Avenir-Heavy"
        label.fontSize = 18
        label.fontColor = .black
        label.verticalAlignmentMode = .center
        label.zPosition = 101
        bg.addChild(label)

        addChild(bg)
        let show = SKAction.fadeIn(withDuration: 0.1)
        let wait = SKAction.wait(forDuration: 1.4)
        let hide = SKAction.fadeOut(withDuration: 0.35)
        bg.alpha = 0.0
        bg.run(.sequence([show, wait, hide, .removeFromParent()]))
    }
}

// --- MARK: - SwiftUI Views

struct ContentView: View {
    @StateObject private var game = GameState()

    var scene: FieldScene {
        let s = FieldScene()
        s.scaleMode = .resizeFill
        s.game = game
        game.scene = s
        return s
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                topStats
                ZStack {
                    SpriteView(scene: scene, options: [.allowsTransparency])
                        .ignoresSafeArea(edges: .bottom)
                        .frame(minHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.1)))
                    VStack { Spacer(); controlsBar }
                }
                burrowsList
                upgrades
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("RatsColony")
            .toolbar { Button("Новый цикл") { /* reserved */ } }
        }
        .preferredColorScheme(.dark)
    }

    private var topStats: some View {
        HStack(spacing: 12) {
            stat("Припасы", value: "\(game.supplies)")
            stat("Крысы", value: "\(game.totalRats)")
            stat("Дом (уров.)", value: "\(game.houseLevel)")
            stat("Износ", value: "\(Int(game.houseWear))%")
        }
    }

    private func stat(_ title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.7))
            Text(value).font(.headline)
        }
        .padding(10)
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var controlsBar: some View {
        HStack {
            Picker("План", selection: $game.plan) {
                ForEach(MissionPlan.allCases) { p in Text(p.rawValue).tag(p) }
            }
            .pickerStyle(.segmented)
            Button(action: game.runMission) {
                Label("Запуск", systemImage: "bolt.fill")
                    .padding(.horizontal, 10).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(game.order.totalSelected == 0)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    private var burrowsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Фаза 1: Подготовка").font(.headline)
            ForEach(game.burrows) { burrow in
                BurrowRow(game: game, burrow: burrow)
            }
        }
    }

    private var upgrades: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Развитие (Фаза 4)").font(.headline)
            HStack {
                Button("Создать нору (120)") { game.createBurrow() }.disabled(game.supplies < 120)
                Button("Ослабить дом (100)") { game.weakenHouse() }.disabled(game.supplies < 100)
                Spacer()
                Button("Сброс выбора") { game.resetSelection() }
            }
        }
    }
}

struct BurrowRow: View {
    @ObservedObject var game: GameState
    @ObservedObject var burrow: Burrow
    @State private var toSend: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(burrow.name).font(.subheadline.bold())
                Spacer()
                Text("ур. \(burrow.level)")
                Text("вмест. \(burrow.capacity)")
                Text("крыс \(burrow.rats)")
            }
            HStack(spacing: 10) {
                Stepper(value: Binding(get: { toSend }, set: { newVal in
                    let capped = clamp(newVal, 0, burrow.rats)
                    toSend = capped
                    game.order.selection[burrow.id] = capped
                }), in: 0...max(0, burrow.rats)) {
                    Text("В отряд: \(toSend)")
                }
                .layoutPriority(2)

                Button("Вербовка +1") { game.recruitRats(in: burrow, amount: 1) }
                    .disabled(game.supplies <= 0 || burrow.rats >= burrow.capacity)

                Button("Апгрейд (\(burrow.upgradeCost))") { game.upgrade(burrow: burrow) }
                    .disabled(!burrow.canUpgrade || game.supplies < burrow.upgradeCost)

                Spacer()
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(10)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// --- MARK: - App Entry

@main
struct RatsColonyGameApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

// --- MARK: - Assets naming (replace with your files)
// Add these images to your Asset Catalog (or rename in code):
//   house  : домик слева (желательно 140x140pt)
//   hunter : хозяин/охотник рядом с домом (90x90pt)
//   rat    : спрайт крысы (34x22pt примерно)
// Optionally:
//   burrow : иконка норы для будущего декора (необязательно в этой версии)
// Если изображения отсутствуют, код подставит цветные прямоугольники как заглушки.

// --- MARK: - Balancing notes
// - Каждый погибший повышает скрытую сложность через totalRatsKilled, что увеличивает риски следующих волн.
// - План "Поиск уязвимости" снижает риски умеренно; "Создание прохода" может сильно помочь, но риск провала.
// - Износ дома (houseWear) растёт от количества добравшихся к дому и пробравшихся внутрь + бонус плана прохода.
// - Победа наступает при houseWear >= 100 (проверьте самостоятельно в UI; можно добавить popup при желании).



#Preview {
    ContentView()
}
