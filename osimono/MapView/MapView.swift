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
        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
    )
    @State private var selectedLocationId: String? = nil
    @StateObject private var locationManager = LocationManager()
    @State private var selectedCategories: Set<String> = ["ライブ", "広告", "カフェ", "その他"]
    @State private var showUserProfile = false
    var oshiId: String
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Map with pins
                Map(coordinateRegion: $region, annotationItems: filteredLocations) { location in
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
                    }
                }
                .edgesIgnoringSafeArea(.all)
                
                // Top header overlay
                VStack {
                    HStack {
                        Spacer()
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                
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
                                        .onAppear{
                                            print("locations      :\(location)")
                                        }
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
                            showAddLocation = true
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
            .onAppear {
                // Show user location when the screen opens
                if let userLocation = locationManager.userLocation {
                    withAnimation {
                        region.center = userLocation.coordinate
                    }
                }
                viewModel.updateCurrentOshi(id: oshiId)
            }
            .onChange(of: oshiId) { newId in
                // 推しが変更されたら更新
                viewModel.updateCurrentOshi(id: newId)
            }
            .fullScreenCover(isPresented: $showAddLocation) {
                EnhancedAddLocationView(
                    viewModel: viewModel,
                    onLocationAdded: { newLocationId in
                        // Set the newly added location as selected
                        selectedLocationId = newLocationId
                        
                        // Find the new location and center the map on it
                        if let newLocation = viewModel.locations.first(where: { $0.id == newLocationId }) {
                            withAnimation {
                                region.center = CLLocationCoordinate2D(
                                    latitude: newLocation.latitude,
                                    longitude: newLocation.longitude
                                )
                            }
                        }
                    }
                )
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(selectedCategories: $selectedCategories)
            }
            .sheet(isPresented: $showUserProfile) {
                UserProfileView()
            }
        }
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
    
    // Filter the locations based on selected categories
    var filteredLocations: [EventLocation] {
        viewModel.locations.filter { location in
            let type = getPinType(for: location)
            return selectedCategories.contains(type.label)
        }
    }
    
    // Determine the pin type based on location data
    func getPinType(for location: EventLocation) -> MapPinView.PinType {
        // First check if the category property exists and has a value
        let mirror = Mirror(reflecting: location)
        let categoryExists = mirror.children.contains { $0.label == "category" }
        
        if categoryExists {
            // Since we know category exists, we can use it directly
            // The compiler error suggests category is not optional, so we use direct access
            switch location.category {
            case "ライブ会場": return .live
            case "ロケ地": return .location
            case "カフェ・飲食店": return .cafe
            case "グッズショップ": return .shop
            case "撮影スポット": return .photo
            case "聖地": return .sacred
            case "その他": return .other
            default: break // Go to title check if none matched
            }
        }
        
        // Fallback to checking title
        if location.title.contains("ライブ") || location.title.contains("コンサート") {
            return .live
        } else if location.title.contains("ロケ") || location.title.contains("撮影地") {
            return .location
        } else if location.title.contains("カフェ") || location.title.contains("レストラン") || location.title.contains("cafe") {
            return .cafe
        } else if location.title.contains("ショップ") || location.title.contains("グッズ") || location.title.contains("shop") {
            return .shop
        } else if location.title.contains("撮影") || location.title.contains("写真") {
            return .photo
        } else if location.title.contains("聖地") {
            return .sacred
        } else {
            return .other
        }
    }
}

//struct MapView_Previews: PreviewProvider {
//    static var previews: some View {
//        MapView()
//    }
//}

// Extension for rounded corners on specific sides
//extension View {
//    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
//        clipShape(RoundedCorner(radius: radius, corners: corners))
//    }
//}
//
//struct RoundedCorner: Shape {
//    var radius: CGFloat = .infinity
//    var corners: UIRectCorner = .allCorners
//
//    func path(in rect: CGRect) -> Path {
//        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
//        return Path(path.cgPath)
//    }
//}
