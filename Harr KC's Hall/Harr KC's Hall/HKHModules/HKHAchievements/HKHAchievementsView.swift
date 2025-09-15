//
//  HKHAchievementsView.swift
//  Harr KC's Hall
//
//

import SwiftUI

struct HKHAchievementsView: View {
    @StateObject var user = ZZUser.shared
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject var viewModel = ZZAchievementsViewModel()
    @State private var index = 0
    var body: some View {
        ZStack {
            
            VStack {
                ZStack {
                    
                    HStack {
                        Image(.achievementsTextHKH)
                            .resizable()
                            .scaledToFit()
                            .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 100:70)
                    }
                    
                    HStack(alignment: .top) {
                        Button {
                            presentationMode.wrappedValue.dismiss()
                            
                        } label: {
                            Image(.backIconHKH)
                                .resizable()
                                .scaledToFit()
                                .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 100:60)
                        }
                        
                        Spacer()
                        
                        ZZCoinBg()
                    }
                }.padding([.top])
                
                Spacer()
                
                HStack(spacing: 20) {
                    ForEach(viewModel.achievements, id: \.self) { item in
                        Image(item.image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 100:200)
                            .opacity(item.isAchieved ? 1:0.5)
                            .onTapGesture {
                                viewModel.achieveToggle(item)
                                if !item.isAchieved {
                                    user.updateUserMoney(for: 10)
                                }
                            }
                    }
                    
                }
                
                Spacer()
            }
        }
        .background(
            ZStack {
                Image(.appBgHKH)
                    .resizable()
                    .ignoresSafeArea()
                    .scaledToFill()
                    
                
                
            }
        )
    }
    
    
}
#Preview {
    HKHAchievementsView()
}
