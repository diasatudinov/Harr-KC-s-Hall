//
//  HKHLevelsVIew.swift
//  Harr KC's Hall
//
//

import SwiftUI

struct HKHLevelsVIew: View {
    private let totalRounds = 12
    @State private var showGame = false
    @Environment(\.presentationMode) var presentationMode
    
    @State var state = GameState()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                ZStack {
                    HStack {
                        Image(.levelsTextHKH)
                            .resizable()
                            .scaledToFit()
                            .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 100:70)
                    }.padding()
                    
                    HStack(alignment: .top) {
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
                    }.padding([.horizontal, .top])
                }
                
                Spacer()
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                    ForEach(1...totalRounds, id: \.self) { round in
                        ZStack {
                            Image(.levelBgHKH)
                                .resizable()
                                .scaledToFit()
                            
                            Text("\(round)")
                                .font(.title)
                                .bold()
                                .foregroundStyle(.white)
                                .padding(12)
                            
                        }.frame(height: ZZDeviceManager.shared.deviceType == .pad ? 200:80)
                            .onTapGesture {
                                showGame = true
                            }
                        
                    }
                }
                .padding(.horizontal, 16)
                Spacer()
            }
            
        }.background(
            ZStack {
                Image(.appBgHKH)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
        )
        .fullScreenCover(isPresented: $showGame) {
            GameView()
        }
    }
}

#Preview {
    HKHLevelsVIew()
}
