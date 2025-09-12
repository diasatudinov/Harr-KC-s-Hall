//
//  HKHDailyView.swift
//  Harr KC's Hall
//
//

import SwiftUI

struct HKHDailyView: View {
    @Environment(\.presentationMode) var presentationMode
           @StateObject private var viewModel = DailyRewardsViewModel()
           
           private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
           private let dayCellHeight: CGFloat = ZZDeviceManager.shared.deviceType == .pad ? 200:108
           var body: some View {
               ZStack {
                   VStack(spacing: 0) {
                       
                       ZStack {
                           
                           LazyVGrid(columns: columns, spacing: 10) {
                               ForEach(1...viewModel.totalDaysCount, id: \.self) { day in
                                   ZStack {
                                       
                                       Image(viewModel.isDayClaimed(day) ? .receivedBgHKH : viewModel.isDayUnlocked(day) ? .getBgHKH : .closedBgHKH)
                                           .resizable()
                                           .scaledToFit()
                                           
                                       VStack(spacing: 5) {
                                           
                                           Text("Day \(day)")
                                               .font(.system(size: 22, weight: .bold))
                                               .foregroundStyle(.black)
                                               .textCase(.uppercase)
                                           Spacer()
                                       }.padding(.top, 10)
                                   }
                                   .frame(width: 105, height: dayCellHeight)
                                   .offset(x: day > 4 ? dayCellHeight/2:0)
                                   .onTapGesture {
                                       viewModel.claimNext()
                                   }
                                   
                               }
                           }.frame(width: ZZDeviceManager.shared.deviceType == .pad ? 800:450)
                       }
                   }.padding(.top, 48)
                   
                   VStack {
                       ZStack {
                           HStack {
                               Image(.dailyTextHKH)
                                   .resizable()
                                   .scaledToFit()
                                   .frame(height: ZZDeviceManager.shared.deviceType == .pad ? 100:72)
                           }
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
                               
                           }
                       }.padding([.horizontal, .top])
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
           }
       }

#Preview {
    HKHDailyView()
}
