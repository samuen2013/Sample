//
//  ContentView.swift
//  test
//
//  Created by 曹盛淵 on 2022/12/5.
//

import SwiftUI

class ViewModel: ObservableObject, StreamingActionProvider {
    @Published var action: StreamingViewAction?
    var actionPublished: Published<StreamingViewAction?> { _action }
    var actionPublisher: Published<StreamingViewAction?>.Publisher { $action }
    
    func startStreaming() {
        action = .startLive(ip: "172.18.59.90", port: 80, streamIndex: 0, channelIndex: 0)
    }
}

struct ContentView: View {
    @StateObject var viewModel = ViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                VStack {
                    Color.black.overlay(
                        StreamingViewWrapper(streamingActionProvider: viewModel)
                            .frame(maxWidth: .infinity)
                    )
                    .clipped()
                    .frame(width: geometry.size.width, height: geometry.size.width * 3/4)
                    .contentShape(.rect)
                    
                    Spacer()
                    
                    HStack(spacing: 0) {
                        Button(action: {
                            viewModel.startStreaming()
                        }) {
                            Text("Play")
                        }
                        .buttonStyle(SolidLargePrimaryButtonStyle())
                    }
                    .frame(height: 50)
                    .padding(.horizontal, 16)
                    .padding(.bottom, geometry.safeAreaInsets.bottomPadding)
                }
                .background(Color(.colorSurface03))
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Streaming test")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarColor(Color(.colorSurface03))
            }
        }
    }
    
    var streamingView: some View {
        StreamingViewWrapper(streamingActionProvider: viewModel)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
