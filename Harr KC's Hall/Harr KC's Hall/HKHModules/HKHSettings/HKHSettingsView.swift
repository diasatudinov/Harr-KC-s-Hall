//
//  HKHSettingsView.swift
//  Harr KC's Hall
//
//

import SwiftUI

struct HKHSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject var settingsVM = CPSettingsViewModel()
    var body: some View {
        ZStack {
            
            VStack {
                
                ZStack {
                    
                    Image(.settingsBgHKH)
                        .resizable()
                        .scaledToFit()
                    
                    
                    VStack(spacing: 8) {
                        Spacer()
                        VStack {
                            
                            Image(.soundTextHKH)
                                .resizable()
                                .scaledToFit()
                                .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 80:25)
                            
                            Button {
                                withAnimation {
                                    settingsVM.soundEnabled.toggle()
                                }
                            } label: {
                                Image(settingsVM.soundEnabled ? .onHKH:.offHKH)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 80:60)
                            }
                        }
                        
                        Image(.languageHKH)
                            .resizable()
                            .scaledToFit()
                            .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 80:100)
                        
                    }.padding(.bottom, 20)
                }.frame(height: ZZDeviceManager.shared.deviceType == .pad ? 88:313)
                
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
}


#Preview {
    HKHSettingsView()
}
