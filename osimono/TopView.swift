//
//  TopView.swift
//  osimono
//
//  Created by Apple on 2025/03/23.
//

import SwiftUI

struct TopView: View {
    
    var body: some View {
                TabView {
                    HStack{
                        ContentView()
                    }
                    
                    .tabItem {
                        Image(systemName: "rectangle.split.2x2")
                            .padding()
                        Text("推しコレ")
                            .padding()
                    }
                    ZStack {
                        TimelineView()
                    }
                    .tabItem {
                        Image(systemName: "calendar.day.timeline.left")
                            .frame(width:1,height:1)
                        Text("年表")
                    }
                    ZStack {
                        MapView()
                    }
                    .tabItem {
                        Image(systemName: "map")
                        Text("マップ")
                    }
                }
            
    }
}

#Preview {
    TopView()
}
