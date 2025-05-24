import MapKit
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import CoreLocation
import Shimmer

struct MapView: View {
    @ObservedObject var viewModel = LocationViewModel()
    @State private var showAddLocation = false
    @State private var showFilterSheet = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6809591, longitude: 139.7673068),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) // Increased span to see more area
    )
    @State private var selectedLocationId: String? = nil
    @StateObject private var locationManager = LocationManager()
    // Start with all categories selected by default
    @State private var selectedCategories: Set<String> = ["ライブ会場", "ロケ地", "カフェ・飲食店", "グッズショップ", "撮影スポット", "聖地巡礼", "その他"]
    @State private var showUserProfile = false
    var oshiId: String
    @State private var showAddOshiForm = false
    @State private var showingOshiAlert = false
    @State private var isAddLocationActive = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Use viewModel.locations directly to ensure all pins are shown
                Map(coordinateRegion: $region, annotationItems: viewModel.locations) { location in
                    MapAnnotation(
                        coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                        anchorPoint: CGPoint(x: 0.5, y: 1.0)
                    ) {
                        MapPinView(
                            imageName: location.imageURL ?? "",
                            isSelected: selectedLocationId == location.id,
                            pinType: getPinType(for: location)
                        )
                        .onTapGesture {
                            withAnimation(.spring()) {
                                if selectedLocationId == location.id {
                                    selectedLocationId = nil
                                } else {
                                    selectedLocationId = location.id
                                    // Add haptic feedback
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }
                            }
                        }
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 4)
                        .zIndex(selectedLocationId == location.id ? 100 : 1) 
                    }
                }
                .edgesIgnoringSafeArea(.all)
                
                // Location Cards
                VStack {
                    Spacer()
                    
                    if !viewModel.locations.isEmpty {
                        ScrollViewReader { scrollProxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(viewModel.locations) { location in
                                        LocationCardView(
                                            location: location,
                                            isSelected: selectedLocationId == location.id,
                                            pinType: getPinType(for: location),
                                            userLocation: locationManager.userLocation,
                                            oshiId: oshiId
                                        )
                                        .id(location.id)
                                        .onTapGesture {
                                            withAnimation {
                                                if selectedLocationId == location.id {
                                                    selectedLocationId = nil
                                                } else {
                                                    selectedLocationId = location.id
                                                    
                                                    // Update map region
                                                    region.center = CLLocationCoordinate2D(
                                                        latitude: location.latitude,
                                                        longitude: location.longitude
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                            .cornerRadius(20, corners: [.topLeft, .topRight])
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: -2)
                            .frame(height: 180)
                            .onChange(of: selectedLocationId) { id in
                                if let id = id {
                                    withAnimation {
                                        scrollProxy.scrollTo(id, anchor: .center)
                                    }
                                }
                            }
                        }
                    } else {
                        Text("推しスポットはまだ登録されていません")
                            .padding()
                            .background(Color.white.opacity(0.9))
                            .cornerRadius(10)
                            .padding(.bottom, 80)
                    }
                }
//                EnhancedAddLocationView(
//                    viewModel: viewModel,
//                    onLocationAdded: { newLocationId in
//                        // Set the newly added location as selected
//                        selectedLocationId = newLocationId
//                        
//                        // Find the new location and center the map on it
//                        if let newLocation = viewModel.locations.first(where: { $0.id == newLocationId }) {
//                            withAnimation {
//                                region.center = CLLocationCoordinate2D(
//                                    latitude: newLocation.latitude,
//                                    longitude: newLocation.longitude
//                                )
//                            }
//                        }
//                    }
//                )
                NavigationLink(
                    destination: EnhancedAddLocationView(
                        viewModel: viewModel,
                        onLocationAdded: { newId in
                            // 追加後の処理は今までと同じ
                            selectedLocationId = newId
                            if let loc = viewModel.locations.first(where: { $0.id == newId }) {
                                withAnimation {
                                    region.center = CLLocationCoordinate2D(
                                        latitude: loc.latitude,
                                        longitude: loc.longitude
                                    )
                                }
                            }
                        }
                    )
                    .navigationBarHidden(true),
                    isActive: $showAddLocation
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .onChange(of: selectedLocationId) { newId in
                if let newId = newId,
                   let selectedLocation = viewModel.locations.first(where: { $0.id == newId }) {
                    withAnimation {
                        region.center = CLLocationCoordinate2D(
                            latitude: selectedLocation.latitude,
                            longitude: selectedLocation.longitude
                        )
                    }
                }
            }
            .overlay(
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        
                        // 現在地ボタン
                        Button(action: {
                            moveToCurrentLocation()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 50, height: 50)
                                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                
                                Image(systemName: "location.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(Color(hex: "6366F1"))
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 10) // Position above the add button
                        
                        // 追加ボタン
                        Button(action: {
                            generateHapticFeedback()
                            if oshiId == "default" {
                                showAddLocation = true
//                                showingOshiAlert = true
                            } else {
                                showAddLocation = true
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color(hex: "6366F1"), Color(hex: "A855F7")]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                    .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, 190) // Position above the card list
                    }
                }
            )
            .overlay(
                ZStack{
                    if showingOshiAlert {
                        OshiAlertView(
                            title: "推しを登録しよう！",
                            message: "推しグッズやSNS投稿を記録する前に、まずは推しを登録してください。",
                            buttonText: "推しを登録する",
                            action: {
                                showAddOshiForm = true
                            },
                            isShowing: $showingOshiAlert
                        )
                        .transition(.opacity)
                        .zIndex(1)
                    }
                }
            )
            .onAppear {
                // Debug all locations
                print("oshiId: \(oshiId)")
                
                // Show user location when the screen opens
                if let userLocation = locationManager.userLocation {
                    withAnimation {
                        region.center = userLocation.coordinate
                    }
                }
                
                // Update view model with oshi ID
                viewModel.updateCurrentOshi(id: oshiId)
                
                // Debug after a delay to ensure data is loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    
                    // Check if locations are loaded correctly
                    if viewModel.locations.isEmpty {
                        print("⚠️ WARNING: No locations loaded")
                    } else {
                        print("✅ Locations loaded successfully")
                    }
                }
            }
            .onChange(of: oshiId) { newId in
                // 推しが変更されたら更新
                viewModel.updateCurrentOshi(id: newId)
            }
            .fullScreenCover(isPresented: $showAddOshiForm) {
                AddOshiView()
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(selectedCategories: $selectedCategories)
            }
            .sheet(isPresented: $showUserProfile) {
                UserProfileView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // 現在地に移動する関数
    func moveToCurrentLocation() {
        // 位置情報の権限をリクエストして現在位置を取得
        locationManager.startUpdatingLocation()
        
        // ハプティックフィードバックを追加
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // 現在位置が利用可能な場合、地図の中心を現在位置に設定
        if let userLocation = locationManager.userLocation?.coordinate {
            withAnimation(.easeInOut(duration: 0.5)) {
                region.center = userLocation
                // ズームレベルを適切に調整
                region.span = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
            }
        }
    }
    
    // Helper function for haptic feedback
    func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // Determine the pin type based on location data
    func getPinType(for location: EventLocation) -> MapPinView.PinType {
        // First check if the category property exists and has a value
        if let category = location.category as String? {
            switch category {
            case "ライブ会場": return .live
                //            case "ロケ地": return .sacred
            case "カフェ・飲食店": return .cafe
            case "グッズショップ": return .shop
            case "撮影スポット": return .photo
            case "聖地巡礼": return .sacred
            case "その他": return .other
            default: break // Go to title check if none matched
            }
        }
        
        // Fallback to checking title
        if location.title.contains("ライブ") || location.title.contains("コンサート") {
            return .live
            //        } else if location.title.contains("ロケ") || location.title.contains("撮影地") {
            //            return .location
        } else if location.title.contains("カフェ") || location.title.contains("レストラン") || location.title.contains("cafe") {
            return .cafe
        } else if location.title.contains("ショップ") || location.title.contains("グッズ") || location.title.contains("shop") {
            return .shop
        } else if location.title.contains("撮影") || location.title.contains("写真") {
            return .photo
        } else if location.title.contains("聖地巡礼") {
            return .sacred
        } else {
            return .other
        }
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView(oshiId: "09073E24-E385-43AC-978E-33425C819285")
    }
}
