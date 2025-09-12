//
//  CPShopViewModel.swift
//  Harr KC's Hall
//
//


import SwiftUI


final class CPShopViewModel: ObservableObject {
    // MARK: – Shop catalogues
    @Published var shopBgItems: [JGItem] = [
        JGItem(name: "bg1", image: "bgImage1ZZ", icon: "gameBgIcon1ZZ", text: "gameBgText1ZZ", price: 100),
        JGItem(name: "bg2", image: "bgImage2ZZ", icon: "gameBgIcon2ZZ", text: "gameBgText2ZZ", price: 100),
        JGItem(name: "bg3", image: "bgImage3ZZ", icon: "gameBgIcon3ZZ", text: "gameBgText3ZZ", price: 100),
        JGItem(name: "bg4", image: "bgImage4ZZ", icon: "gameBgIcon4ZZ", text: "gameBgText4ZZ", price: 100),

    ]
    
    // MARK: – Bought
    @Published var boughtBgItems: [JGItem] = [
        JGItem(name: "bg1", image: "bgImage1CP", icon: "gameBgIcon1CP", text: "gameBgText1CP", price: 100),
    ] {
        didSet { saveBoughtBg() }
    }
    
    // MARK: – Current selections
    @Published var currentBgItem: JGItem? {
        didSet { saveCurrentBg() }
    }
    
    
    // MARK: – UserDefaults keys
    private let bgKey            = "currentBgJG1"
    private let boughtBgKey      = "boughtBgJG1"
    
    // MARK: – Init
    init() {
        loadCurrentBg()
        loadBoughtBg()
                
    }
    
    // MARK: – Save / Load Backgrounds
    private func saveCurrentBg() {
        guard let item = currentBgItem,
              let data = try? JSONEncoder().encode(item)
        else { return }
        UserDefaults.standard.set(data, forKey: bgKey)
    }
    private func loadCurrentBg() {
        if let data = UserDefaults.standard.data(forKey: bgKey),
           let item = try? JSONDecoder().decode(JGItem.self, from: data) {
            currentBgItem = item
        } else {
            currentBgItem = shopBgItems.first
        }
    }
    private func saveBoughtBg() {
        guard let data = try? JSONEncoder().encode(boughtBgItems) else { return }
        UserDefaults.standard.set(data, forKey: boughtBgKey)
    }
    private func loadBoughtBg() {
        if let data = UserDefaults.standard.data(forKey: boughtBgKey),
           let items = try? JSONDecoder().decode([JGItem].self, from: data) {
            boughtBgItems = items
        }
    }
    
    // MARK: – Example buy action
    func buy(_ item: JGItem, category: JGItemCategory) {
        switch category {
        case .background:
            guard !boughtBgItems.contains(item) else { return }
            boughtBgItems.append(item)
        case .skin: break
           
        }
    }
    
    func isPurchased(_ item: JGItem, category: JGItemCategory) -> Bool {
        switch category {
        case .background:
            return boughtBgItems.contains(where: { $0.name == item.name })
        case .skin:
            return false
        }
    }

    func selectOrBuy(_ item: JGItem, user: ZZUser, category: JGItemCategory) {
        
        switch category {
        case .background:
            if isPurchased(item, category: .background) {
                currentBgItem = item
            } else {
                guard user.money >= item.price else {
                    return
                }
                user.minusUserMoney(for: item.price)
                buy(item, category: .background)
            }
        case .skin: break
           
        }
    }
    
    func isMoneyEnough(item: JGItem, user: ZZUser, category: JGItemCategory) -> Bool {
        user.money >= item.price
    }
    
    func isCurrentItem(item: JGItem, category: JGItemCategory) -> Bool {
        switch category {
        case .background:
            guard let currentItem = currentBgItem, currentItem.name == item.name else {
                return false
            }
            
            return true
            
        case .skin:
            
            
            return true
        }
    }
    
    func nextCategory(category: JGItemCategory) -> JGItemCategory {
        if category == .skin {
            return .background
        } else {
            return .skin
        }
    }
}

enum JGItemCategory: String {
    case background = "background"
    case skin = "skin"
}

struct JGItem: Codable, Hashable {
    var id = UUID()
    var name: String
    var image: String
    var icon: String
    var text: String
    var price: Int
}
