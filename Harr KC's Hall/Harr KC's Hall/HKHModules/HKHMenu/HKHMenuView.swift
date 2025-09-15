//
//  HKHMenuView.swift
//  Harr KC's Hall
//
//

import SwiftUI

struct HKHMenuView: View {
    @State private var showGame = false
    @State private var showShop = false
    @State private var showAchievement = false
    @State private var showMiniGames = false
    @State private var showSettings = false
    @State private var showCalendar = false
    @State private var showDailyReward = false
    
    @StateObject var shopVM = CPShopViewModel()
    
    var body: some View {
        
        ZStack {
            
            
            VStack(spacing: 0) {
                
                HStack {
                    
                    Image(.loaderLogoHKH)
                        .resizable()
                        .scaledToFit()
                        .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 140:85)
                        .cornerRadius(20)
                    Spacer()
                    ZZCoinBg()
                }.padding(20)
                Spacer()
                
                
                VStack(spacing: 20) {
                    
                    
                    
                    VStack {
                        Button {
                            showGame = true
                        } label: {
                            Image(.playIconHKH)
                                .resizable()
                                .scaledToFit()
                                .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 140:82)
                        }
                        
                        HStack {
                            
                            Button {
                                showAchievement = true
                            } label: {
                                Image(.achievementsIconHKH)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 140:72)
                            }
                            
                            Button {
                                showShop = true
                            } label: {
                                Image(.shopIconHKH)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 140:72)
                            }
                            
                            Button {
                                withAnimation {
                                    showDailyReward = true
                                }
                            } label: {
                                Image(.dailyIconHKH)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 100:72)
                            }
                        }
                    }
                }
                
                Spacer()
                
                HStack {
                    Button {
                        showSettings = true
                    } label: {
                        Image(.settingsIconHKH)
                            .resizable()
                            .scaledToFit()
                            .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 100:50)
                    }
                    
                    Spacer()
                }
                Spacer()
            }
            
            
            
        }.frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Image(.appBgHKH)
                        .resizable()
                        .edgesIgnoringSafeArea(.all)
                        .scaledToFill()
                }
            )
            .fullScreenCover(isPresented: $showGame) {
                //                LevelPickerView()
            }
            .fullScreenCover(isPresented: $showAchievement) {
                HKHAchievementsView()
            }
            .fullScreenCover(isPresented: $showShop) {
                HKHShopView(viewModel: shopVM)
            }
            .fullScreenCover(isPresented: $showSettings) {
                HKHSettingsView()
            }
            .fullScreenCover(isPresented: $showDailyReward) {
                HKHDailyView()
            }
    }
}

#Preview {
    HKHMenuView()
}
