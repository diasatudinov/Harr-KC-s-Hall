//
//  HKHShopView.swift
//  Harr KC's Hall
//
//

import SwiftUI

struct HKHShopView: View {
    @StateObject var user = ZZUser.shared
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: CPShopViewModel
    @State var category: JGItemCategory?
    var body: some View {
        ZStack {
            
            if let category = category {
                VStack {
                    
                    Image(category == .skin ? .skinsTextHKH : .bgTextHKH)
                        .resizable()
                        .scaledToFit()
                        .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 100:75)
                    HStack {
                        
                        ForEach(category == .skin ? viewModel.shopSkinItems :viewModel.shopBgItems, id: \.self) { item in
                            achievementItem(item: item, category: category == .skin ? .skin : .background)
                            
                        }
                        
                        
                    }
                }
            } else {
                VStack(spacing: 35) {
                    Image(.shopTextHKH)
                        .resizable()
                        .scaledToFit()
                        .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 100:70)
                    
                    HStack(spacing: 60) {
                        Button {
                            category = .skin
                        } label: {
                            Image(.skinsTextHKH)
                                .resizable()
                                .scaledToFit()
                                .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 100:75)
                        }
                        
                        Button {
                            category = .background
                        } label: {
                            Image(.bgTextHKH)
                                .resizable()
                                .scaledToFit()
                                .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 100:75)
                        }
                    }
                }
            }
            
            
            
            VStack {
                HStack {
                    Button {
                        if category == nil {
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            category = nil
                        }
                        
                    } label: {
                        Image(.backIconHKH)
                            .resizable()
                            .scaledToFit()
                            .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 100:50)
                    }
                    
                    Spacer()
                    
                    ZZCoinBg()
                    
                    
                    
                }.padding()
                Spacer()
                
                
                
            }
        }.frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Image(.appBgHKH)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                }
            )
    }
    
    @ViewBuilder func achievementItem(item: JGItem, category: JGItemCategory) -> some View {
        ZStack {
            
            Image(item.icon)
                .resizable()
                .scaledToFit()
            VStack {
                Spacer()
                Button {
                    viewModel.selectOrBuy(item, user: user, category: category)
                } label: {
                    
                    if viewModel.isPurchased(item, category: category) {
                        ZStack {
                            Image(viewModel.isCurrentItem(item: item, category: category) ? .usedBtnBgHKH : .useBtnBgHKH)
                                .resizable()
                                .scaledToFit()
                            
                        }.frame(height: ZZDeviceManager.shared.deviceType == .pad ? 50:42)
                        
                    } else {
                        Image(.hundredCoinHKH)
                            .resizable()
                            .scaledToFit()
                            .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 50:42)
                            .opacity(viewModel.isMoneyEnough(item: item, user: user, category: category) ? 1:0.6)
                    }
                    
                    
                }
            }.offset(y: 8)
            
        }.frame(height: ZZDeviceManager.shared.deviceType == .pad ? 300:200)
        
    }
}


#Preview {
    HKHShopView(viewModel: CPShopViewModel())
}
