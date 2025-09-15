//
//  ZZAchievementsViewModel.swift
//  Harr KC's Hall
//
//


import SwiftUI

class ZZAchievementsViewModel: ObservableObject {
    
    @Published var achievements: [NEGAchievement] = [
        NEGAchievement(image: "achieve1ImageHKH", title: "achieve1TextHKH", isAchieved: false),
        NEGAchievement(image: "achieve2ImageHKH", title: "achieve2TextHKH", isAchieved: false),
        NEGAchievement(image: "achieve3ImageHKH", title: "achieve3TextHKH", isAchieved: false),
        NEGAchievement(image: "achieve4ImageHKH", title: "achieve4TextHKH", isAchieved: false),
        NEGAchievement(image: "achieve5ImageHKH", title: "achieve5TextHKH", isAchieved: false),
    ] {
        didSet {
            saveAchievementsItem()
        }
    }
        
    init() {
        loadAchievementsItem()
        
    }
    
    private let userDefaultsAchievementsKey = "achievementsKeyHKH"
    
    func achieveToggle(_ achive: NEGAchievement) {
        guard let index = achievements.firstIndex(where: { $0.id == achive.id })
        else {
            return
        }
        achievements[index].isAchieved.toggle()
        
    }
   
    
    
    func saveAchievementsItem() {
        if let encodedData = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(encodedData, forKey: userDefaultsAchievementsKey)
        }
        
    }
    
    func loadAchievementsItem() {
        if let savedData = UserDefaults.standard.data(forKey: userDefaultsAchievementsKey),
           let loadedItem = try? JSONDecoder().decode([NEGAchievement].self, from: savedData) {
            achievements = loadedItem
        } else {
            print("No saved data found")
        }
    }
}

struct NEGAchievement: Codable, Hashable, Identifiable {
    var id = UUID()
    var image: String
    var title: String
    var isAchieved: Bool
}
