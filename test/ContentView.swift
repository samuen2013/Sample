//
//  ContentView.swift
//  test
//
//  Created by 曹盛淵 on 2022/12/5.
//

import SwiftUI

class ViewModel: ObservableObject, StreamingActionProvider {
    @Published var action: StreamingViewAction?
    var actionPublisher: Published<StreamingViewAction?>.Publisher { $action }
    
    func startStreaming(ip: String, port: Int, streamIndex: Int, channelIndex: Int) {
//        action = .startLive(ip: "172.18.59.90", port: 80, streamIndex: 0, channelIndex: 0)
        action = .startNVRLive(ip: ip, port: port, streamIndex: streamIndex, channelIndex: channelIndex)
    }
    
    func stopStreaming() {
        action = .stop
    }
}

let channelRange: ClosedRange<Int> = 0...31

struct ContentView: View {
    @StateObject var viewModel = ViewModel()
    
    @State private var ip = "172.18.1.232"
    @State private var port: Double? = 80
    @AppStorage("connectDeviceUser") private var connectDeviceUser = "root"
    @AppStorage("connectDevicePassword") private var connectDevicePassword = "vssdtest123"
    
    private let streams: [Int] = [0, 1]
    @State private var streamIndex = 0
    private let channels: [Int] = Array(channelRange)
    @State private var channelIndex = 0
    
    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                ScrollView {
                    Color.black.overlay(
                        StreamingViewWrapper(streamingActionProvider: viewModel)
                            .frame(maxWidth: .infinity)
                    )
                    .clipped()
                    .frame(width: geometry.size.width, height: geometry.size.width * 3/4)
                    
                    settings

                    Spacer()
                    
                    buttons
                        .padding(.bottom, geometry.safeAreaInsets.bottomPadding)
                }
                .background(Color(.colorSurface02))
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
    
    var settings: some View {
        VStack(spacing: 0) {
            Group {
                TextField("ip", text: $ip, prompt: Text("ip"))
                TextField("port", value: $port, format: .number, prompt: Text("port"))
            }
            .padding()
            .background(Color(.colorSurface03))
            .padding(.top, 8)
            .padding(.horizontal, 16)
            
            HStack(spacing: 0) {
                Group {
                    TextField("user", text: $connectDeviceUser, prompt: Text("user"))
                    TextField("password", text: $connectDevicePassword, prompt: Text("password"))
                }
                .padding()
                .background(Color(.colorSurface03))
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
            
            HStack {
                Text("Stream")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(Color(.colorText05))
                
                Picker("streamIndex", selection: $streamIndex) {
                    Text("\(streams[0])").tag(0)
                    Text("\(streams[1])").tag(1)
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
            
            HStack {
                Text("Channel")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(Color(.colorText05))
                Picker("channelIndex", selection: $channelIndex) {
                    ForEach(channelRange, id: \.self) { index in
                        Text("\(channels[index])").tag(index)
                    }
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal, 16)
        }
    }
    
    var buttons: some View {
        VStack(spacing: 8) {
            Button(action: {
                viewModel.startStreaming(ip: ip, port: Int(port!), streamIndex: streamIndex, channelIndex: channelIndex)
            }) {
                Text("Play")
            }
            .buttonStyle(SolidLargePrimaryButtonStyle())
            .frame(height: 50)
            .padding(.horizontal, 16)
            
            Button(action: {
                viewModel.stopStreaming()
            }) {
                Text("Stop")
            }
            .buttonStyle(SolidLargePrimaryButtonStyle())
            .frame(height: 50)
            .padding(.horizontal, 16)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
