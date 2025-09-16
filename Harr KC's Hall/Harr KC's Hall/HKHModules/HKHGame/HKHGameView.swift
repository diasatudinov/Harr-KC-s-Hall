//
//  ContentView.swift
//  Harr KC's Hall
//
//

import SwiftUI
import SpriteKit

// MARK: - Game Model

@MainActor
final class GameState: ObservableObject {
    @Published var rats: Int = 10
    @Published var supplies: Int = 10
    @Published var houseHP: Int = 100
    @Published var isRunning: Bool = false
    @Published var phaseBanner: String? = nil

    // Норы
    @Published var burrowCount: Int = 3
    let burrowCapacity: Int = 8
    let burrowCost: Int = 200
    var maxRatsPerPhase: Int { burrowCount * burrowCapacity }

    // Константы баланса
    let ratsPerRound: Int = 10
    let houseDamagePerRat: Int = 5

    weak var scene: FieldScene?

    func startRound() {
        guard !isRunning else { return }
        guard houseHP > 0 else { return }
        // В начале каждой фазы норы восстанавливают запас крыс
        rats = maxRatsPerPhase
        guard rats > 0 else { return }

        isRunning = true
        let toSend = min(ratsPerRound, rats)
        rats -= toSend // оставшиеся в норах на эту фазу (HUD покажет во время фазы)
        scene?.startRound(spawnCount: toSend)
    }

    func onRatKilled() { /* резерв под будущую экономику */ }

    func onRatReachedHouse() {
        supplies += 30
        houseHP = max(0, houseHP - houseDamagePerRat)
        if houseHP == 0 {
            ZZUser.shared.updateUserMoney(for: 100)
            scene?.forceEndRound(reason: "1")
        }
    }

    func onRoundFinished(reason: String) {
        isRunning = false
        showPhaseBanner(reason)
    }

    func addBurrow() {
        guard !isRunning, supplies >= burrowCost else { return }
        supplies -= burrowCost
        burrowCount += 1
        scene?.addRandomBurrow()
    }

    private func showPhaseBanner(_ text: String) {
        phaseBanner = text
    }
}

// MARK: - Physics

struct PhysicsMask {
    static let none: UInt32   = 0
    static let rat: UInt32    = 1 << 0
    static let bullet: UInt32 = 1 << 1
}

// MARK: - SpriteKit Scene

final class FieldScene: SKScene, SKPhysicsContactDelegate {
    let shopVM = CPShopViewModel()
    weak var game: GameState?

    private var house: SKSpriteNode!
    private var hunter: SKSpriteNode!
    private var burrows: [SKSpriteNode] = []

    private var ratsOnField: Int = 0
    private var roundInProgress = false

    private var leftX: CGFloat { size.width * 0.18 }

    override func didMove(to view: SKView) {
        backgroundColor = .clear // полностью прозрачный фон
        physicsWorld.contactDelegate = self
        buildWorld()
        startHunterLoop()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        removeAllChildren(); burrows.removeAll()
        buildWorld()
    }

    private func buildWorld() {
        // Дом слева
        house = SKSpriteNode(imageNamed: "house")
        if house.texture == nil { house = SKSpriteNode(color: .brown, size: CGSize(width: 140, height: 140)) }
        else { house.size = CGSize(width: 140, height: 140) }
        house.position = CGPoint(x: leftX, y: size.height * 0.58)
        house.zPosition = 10
        addChild(house)

        // Охотник рядом с домом
        hunter = SKSpriteNode(imageNamed: "hunter")
        if hunter.texture == nil { hunter = SKSpriteNode(color: .red, size: CGSize(width: 90, height: 90)) }
        else { hunter.size = CGSize(width: 90, height: 90) }
        hunter.position = CGPoint(x: leftX + 40, y: size.height * 0.36)
        hunter.zPosition = 11
        addChild(hunter)

        // Норы: привести к количеству из game?.burrowCount (по умолчанию 3)
        let desired = game?.burrowCount ?? 3
        ensureBurrowCount(desired)
    }

    private func ensureBurrowCount(_ desired: Int) {
        // Добавить недостающие
        if burrows.count < desired {
            for _ in 0..<(desired - burrows.count) { addRandomBurrow() }
        }
        // Удалить лишние (с конца)
        if burrows.count > desired {
            let extra = burrows.count - desired
            let toRemove = burrows.suffix(extra)
            toRemove.forEach { n in n.removeFromParent() }
            burrows.removeLast(extra)
        }
    }

    // Публично: добавить нору в случайном месте справа от центра
    func addRandomBurrow() {
        let node = makeRandomBurrow()
        addChild(node)
        burrows.append(node)
    }

    private func makeRandomBurrow() -> SKSpriteNode {
        let minX = size.width * 0.58
        let maxX = size.width * 0.9
        let y = size.height * CGFloat([0.28, 0.46, 0.64, 0.74].randomElement()!)
        var node = SKSpriteNode(imageNamed: "burrow")
        if node.texture == nil { node = SKSpriteNode(color: .darkGray, size: CGSize(width: 48, height: 32)) }
        else { node.size = CGSize(width: 48, height: 32) }
        node.position = CGPoint(x: CGFloat.random(in: minX...maxX), y: y)
        node.zPosition = 6
        return node
    }

    // MARK: Round control

    func startRound(spawnCount: Int) {
        guard !roundInProgress else { return }
        roundInProgress = true
        ratsOnField = spawnCount
        for i in 0..<spawnCount {
            let delay = 0.12 * Double(i)
            let burrow = burrows.randomElement() ?? addAndReturnOne()
            run(.sequence([.wait(forDuration: delay), .run { [weak self] in self?.spawnRat(from: burrow) }]))
        }
    }

    private func addAndReturnOne() -> SKSpriteNode {
        addRandomBurrow(); return burrows.last!
    }

    private func spawnRat(from burrow: SKNode) {
        guard let currentSkin = shopVM.currentSkinItem else { return }
        var rat = SKSpriteNode(imageNamed: currentSkin.image)
        if rat.texture == nil { rat = SKSpriteNode(color: .gray, size: CGSize(width: 32, height: 22)) }
        else { rat.size = CGSize(width: 32, height: 22) }
        rat.name = "rat"
        rat.position = burrow.position
        rat.zPosition = 8
        rat.physicsBody = SKPhysicsBody(circleOfRadius: max(rat.size.width, rat.size.height)/2)
        rat.physicsBody?.isDynamic = false
        rat.physicsBody?.categoryBitMask = PhysicsMask.rat
        rat.physicsBody?.collisionBitMask = PhysicsMask.none
        rat.physicsBody?.contactTestBitMask = PhysicsMask.bullet
        rat.xScale = -abs(rat.xScale)
        addChild(rat)

        let target = houseDoorPoint()
        let distance = hypot(rat.position.x - target.x, rat.position.y - target.y)
        let speed: CGFloat = 140
        let duration = TimeInterval(distance / speed)
        let path = SKAction.move(to: target, duration: duration)
        path.timingMode = .easeIn
        rat.run(.sequence([path, .run { [weak self, weak rat] in
            guard let self = self, let r = rat else { return }
            self.ratReachedHouse(rat: r)
        }]))
    }

    private func houseDoorPoint() -> CGPoint {
        CGPoint(x: house.position.x + house.size.width*0.1, y: house.position.y - 10)
    }

    private func ratReachedHouse(rat: SKSpriteNode) {
        rat.removeAllActions(); rat.removeFromParent()
        game?.onRatReachedHouse()
        if game?.houseHP == 0 { return }
        concludeOneRat()
    }

    private func concludeOneRat() {
        ratsOnField -= 1
        if ratsOnField <= 0 {
            roundInProgress = false
            game?.onRoundFinished(reason: "Фаза завершена: все крысы уничтожены")
        }
    }

    // MARK: Hunter logic

    private func startHunterLoop() {
        hunter.removeAction(forKey: "hunterLoop")
        let loop = SKAction.repeatForever(.sequence([
            .wait(forDuration: 0.45),
            .run { [weak self] in self?.tryFire() }
        ]))
        hunter.run(loop, withKey: "hunterLoop")
    }

    private func tryFire() {
        guard roundInProgress else { return }
        guard let target = closestRat(to: hunter.position) else { return }
        fireBullet(from: hunter.position, to: target)
    }

    private func closestRat(to point: CGPoint) -> SKSpriteNode? {
        var nearest: SKSpriteNode?
        var best: CGFloat = .greatestFiniteMagnitude
        enumerateChildNodes(withName: "rat") { node, _ in
            let d = hypot(node.position.x - point.x, node.position.y - point.y)
            if d < best { best = d; nearest = node as? SKSpriteNode }
        }
        return nearest
    }

    private func fireBullet(from: CGPoint, to target: SKSpriteNode) {
        let bullet = SKShapeNode(circleOfRadius: 3)
        bullet.fillColor = .white
        bullet.strokeColor = .clear
        bullet.position = from
        bullet.zPosition = 20
        bullet.name = "bullet"
        let body = SKPhysicsBody(circleOfRadius: 3)
        body.isDynamic = true
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PhysicsMask.bullet
        body.collisionBitMask = PhysicsMask.none
        body.contactTestBitMask = PhysicsMask.rat
        bullet.physicsBody = body
        addChild(bullet)

        let distance = hypot(from.x - target.position.x, from.y - target.position.y)
        let speed: CGFloat = 520
        let duration = TimeInterval(distance / speed)
        let move = SKAction.move(to: target.position, duration: duration)
        let vanish = SKAction.sequence([.fadeOut(withDuration: 0.05), .removeFromParent()])
        bullet.run(.sequence([move, vanish]))
    }

    // MARK: Physics Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.categoryBitMask
        let b = contact.bodyB.categoryBitMask
        if (a == PhysicsMask.bullet && b == PhysicsMask.rat) || (b == PhysicsMask.bullet && a == PhysicsMask.rat) {
            if let bullet = (a == PhysicsMask.bullet ? contact.bodyA.node : contact.bodyB.node) as? SKNode,
               let rat = (a == PhysicsMask.rat ? contact.bodyA.node : contact.bodyB.node) as? SKSpriteNode {
                bullet.removeAllActions(); bullet.removeFromParent()
                kill(rat: rat)
            }
        }
    }

    private func kill(rat: SKSpriteNode) {
        rat.removeAllActions()
        rat.run(.sequence([.fadeOut(withDuration: 0.05), .removeFromParent()]))
        game?.onRatKilled()
        concludeOneRat()
    }

    // Принудительное завершение фазы (например, дом разрушен)
    func forceEndRound(reason: String) {
        // Принудительно завершаем фазу: чистим и сбрасываем счётчики
        roundInProgress = false
        ratsOnField = 0
        removeAll(ofName: "rat")
        removeAll(ofName: "bullet")
        game?.onRoundFinished(reason: reason)
    }

    private func removeAll(ofName name: String) {
        var victims: [SKNode] = []
        enumerateChildNodes(withName: name) { node, _ in victims.append(node) }
        victims.forEach { $0.removeAllActions(); $0.removeFromParent() }
    }
}

//// MARK: - SwiftUI Shell
//
struct GameView: View {
    @Environment(\.presentationMode) var presentationMode

    @StateObject private var game = GameState()
    @State private var scene = FieldScene() 
    @StateObject private var shopVM = CPShopViewModel()
    @State private var openBtns = false
    var body: some View {
        ZStack {
            SpriteView(scene: scene, options: [.allowsTransparency])
                .ignoresSafeArea()
                .background(Color.clear)
                .onAppear {
                    // Конфигурируем один раз
                    if scene.game == nil {
                        scene.scaleMode = .resizeFill
                        scene.game = game
                        game.scene = scene
                    }
                }
            
            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 0) {
                        Image(.homeIconHKH)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                        Rectangle()
                            .frame(width: CGFloat(game.houseHP * 2), height: 25 )
                            .foregroundStyle(.yellow)
                            .cornerRadius(5)
                    }
                    Spacer()
                }.padding()
                
                Spacer()
            }
            // HUD — top-right
            HStack {
                Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                let ratsHUD = game.isRunning ? game.rats : game.maxRatsPerPhase
                
                ZStack {
                    Image(.supBgHKH)
                        .resizable()
                        .scaledToFit()
                    
                    Text("\(game.supplies)")
                        .font(.system(size: ZZDeviceManager.shared.deviceType == .pad ? 45:25, weight: .black))
                        .foregroundStyle(.white)
                        .textCase(.uppercase)
                        .offset(x: 15)
                }.frame(height: 50)
                
                ZStack {
                    Image(.ratBgHKH)
                        .resizable()
                        .scaledToFit()
                    
                    Text("\(ratsHUD)")
                        .font(.system(size: ZZDeviceManager.shared.deviceType == .pad ? 45:25, weight: .black))
                        .foregroundStyle(.white)
                        .textCase(.uppercase)
                        .offset(x: 15)
                }.frame(height: 50)
                Spacer()
            }
            .padding(12)
        }
            
            
            // Bottom controls: Add burrow (left) / Start (right)
            VStack {
                
                Spacer()
                
                HStack(alignment: .bottom) {
                    
                    Image(.hammerBtnHKH)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .onTapGesture {
                            if !game.isRunning {
                                openBtns.toggle()
                            }
                        }
                    
                    if openBtns {
                        
                        Image(.offBtnHKH)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                        
                        Button {
                            game.addBurrow()
                        } label: {
                            Image(.holeBuyBtnHKH)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                                .opacity(game.supplies < game.burrowCost ? 0.5:1)
                        }
                        .disabled(game.isRunning || game.supplies < game.burrowCost)
                        
                    }
                    
                    
                    Spacer()
                    
                    Button {
                        game.startRound()
                    } label: {
                        Image(.beginBtnHKH)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                    }
                    .opacity(game.isRunning || game.houseHP == 0 ? 0.5:1)
                    .disabled(game.isRunning || game.houseHP == 0)
                }
                .padding(.bottom, 8)
            }
            
            VStack {
                HStack {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        
                    } label: {
                        Image(.backIconHKH)
                            .resizable()
                            .scaledToFit()
                            .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 100:50)
                    }
                    Spacer()
                }
                Spacer()
            }.padding()
            
            if let banner = game.phaseBanner {
                Color.black.opacity(0.7).ignoresSafeArea()
                ZStack(alignment: .center) {
                    if banner == "1" {
                        Image(.winBgHKH)
                            .resizable()
                            .scaledToFit()
                        
                        VStack {
                            Spacer()
                            Button {
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                Image(.nextLevelBtnHKH)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 50)
                            }
                            
                            Button {
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                Image(.menuBtnHKH)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 50)
                            }
                        }.padding(.bottom, 20)
                        
                    } else {
                        Image(.loseBgHKH)
                            .resizable()
                            .scaledToFit()
                        
                        VStack {
                            Button {
                                game.phaseBanner = nil
                            } label: {
                                Image(.retryBtnHKH)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 50)
                            }
                            
                            Button {
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                Image(.menuBtnHKH)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 50)
                            }
                        }
                    }
                }.frame(height: 250)
                
            }
            
        }.background {
            ZStack {
                if let item = shopVM.currentBgItem {
                    Image(item.image)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                }
                
            }
        }
    }

    private func stat(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.primary.opacity(0.7))
            Text(value).font(.headline)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    GameView()
}
