import MapKit
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import CoreLocation
import Shimmer

struct MapView: View {
    @StateObject  var viewModel = LocationViewModel()
    @State private var showAddLocation = false
    @State private var showFilterSheet = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6809591, longitude: 139.7673068),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var selectedLocationId: String? = nil
    @StateObject private var locationManager = LocationManager()
    @State private var selectedCategories: Set<String> = ["ライブ会場", "ロケ地", "カフェ・飲食店", "グッズショップ", "撮影スポット", "聖地巡礼", "その他"]
    @State private var showUserProfile = false
    var oshiId: String
    @State private var showAddOshiForm = false
    @State private var showingOshiAlert = false
    @State private var isAddLocationActive = false
    
    // 編集機能用の状態
    @State private var showEditActionSheet = false
    @State private var showEditView = false
    @State private var showDeleteAlert = false
    @State private var selectedEditLocation: EventLocation? = nil

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                mapView
                locationCardsView
                hiddenNavigationLinks
            }
            .onChange(of: selectedLocationId, perform: handleLocationSelection)
            .overlay(controlButtonsOverlay)
            .overlay(alertOverlay)
            .onAppear(perform: handleViewAppear)
            .onChange(of: oshiId, perform: handleOshiIdChange)
            .fullScreenCover(isPresented: $showAddOshiForm) {
                AddOshiView()
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(selectedCategories: $selectedCategories)
            }
            .sheet(isPresented: $showUserProfile) {
                UserProfileView()
            }
            .actionSheet(isPresented: $showEditActionSheet, content: editActionSheet)
            .alert(isPresented: $showDeleteAlert, content: deleteAlert)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - View Components
    
    private var mapView: some View {
        Map(coordinateRegion: $region, annotationItems: viewModel.locations) { location in
            MapAnnotation(
                coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                anchorPoint: CGPoint(x: 0.5, y: 1.0)
            ) {
                mapPinView(for: location)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private func mapPinView(for location: EventLocation) -> some View {
        MapPinView(
            imageName: location.imageURL ?? "",
            isSelected: selectedLocationId == location.id,
            pinType: getPinType(for: location)
        )
        .onTapGesture {
            handlePinTap(for: location)
        }
        .id(location.id)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 4)
        .zIndex(selectedLocationId == location.id ? 100 : 1)
    }
    
    private var locationCardsView: some View {
        VStack {
            Spacer()
            
            if !viewModel.locations.isEmpty {
                locationCardsScrollView
            } else {
                emptyStateView
            }
        }
    }
    
    private var locationCardsScrollView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(viewModel.locations) { location in
                        locationCardView(for: location)
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
    }
    
    private func locationCardView(for location: EventLocation) -> some View {
        LocationCardView(
            location: location,
            isSelected: selectedLocationId == location.id,
            pinType: getPinType(for: location),
            userLocation: locationManager.userLocation,
            oshiId: oshiId,
            onEditTapped: {
                handleEditTapped(for: location)
            }
        )
        .environmentObject(viewModel)
        .id(location.id)
        .onTapGesture {
            handleCardTap(for: location)
        }
    }
    
    private var emptyStateView: some View {
        Text("推しスポットはまだ登録されていません")
            .padding()
            .background(Color.white.opacity(0.9))
            .cornerRadius(10)
            .padding(.bottom, 80)
    }
    
    private var hiddenNavigationLinks: some View {
        Group {
            NavigationLink(
                destination: addLocationView,
                isActive: $showAddLocation
            ) {
                EmptyView()
            }
            .hidden()
            
            NavigationLink(
                destination: editLocationView,
                isActive: $showEditView
            ) {
                EmptyView()
            }
            .hidden()
        }
    }
    
    private var addLocationView: some View {
        EnhancedAddLocationView(
            viewModel: viewModel,
            onLocationAdded: { newId in
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
        .navigationBarHidden(true)
    }
    
    private var editLocationView: some View {
        Group {
            if let location = selectedEditLocation {
                EditLocationView(
                    viewModel: viewModel,
                    existingLocation: location,
                    onLocationUpdated: { updatedLocationId in
                        print("Location updated: \(updatedLocationId)")
                        showEditView = false
                        selectedEditLocation = nil
                    }
                )
                .navigationBarHidden(true)
            } else {
                EmptyView()
            }
        }
    }
    
    private var controlButtonsOverlay: some View {
        HStack {
            Spacer()
            VStack {
                Spacer()
                
                currentLocationButton
                addLocationButton
            }
        }
    }
    
    private var currentLocationButton: some View {
        Button(action: moveToCurrentLocation) {
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
        .padding(.bottom, 10)
    }
    
    private var addLocationButton: some View {
        Button(action: handleAddLocationTap) {
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
        .padding(.bottom, 190)
    }
    
    private var alertOverlay: some View {
        ZStack {
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
    }
    
    // MARK: - Action Handlers
    
    private func handlePinTap(for location: EventLocation) {
        withAnimation(.spring()) {
            if selectedLocationId == location.id {
                selectedLocationId = nil
            } else {
                selectedLocationId = location.id
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        }
    }
    
    private func handleCardTap(for location: EventLocation) {
        withAnimation {
            if selectedLocationId == location.id {
                selectedLocationId = nil
            } else {
                selectedLocationId = location.id
                region.center = CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
            }
        }
    }
    
    private func handleEditTapped(for location: EventLocation) {
        selectedEditLocation = location
        showEditActionSheet = true
    }
    
    private func handleLocationSelection(_ newId: String?) {
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
    
    private func handleViewAppear() {
        print("oshiId: \(oshiId)")
        
        if let userLocation = locationManager.userLocation {
            withAnimation {
                region.center = userLocation.coordinate
            }
        }
        
        viewModel.updateCurrentOshi(id: oshiId)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if viewModel.locations.isEmpty {
                print("⚠️ WARNING: No locations loaded")
            } else {
                print("✅ Locations loaded successfully")
            }
        }
    }
    
    private func handleOshiIdChange(_ newId: String) {
        viewModel.updateCurrentOshi(id: newId)
    }
    
    private func handleAddLocationTap() {
        generateHapticFeedback()
        showAddLocation = true
    }
    
    // MARK: - Alert and ActionSheet
    
    private func editActionSheet() -> ActionSheet {
        ActionSheet(
            title: Text("スポットの操作"),
            message: Text(selectedEditLocation?.title ?? ""),
            buttons: [
                .default(Text("編集")) {
                    generateHapticFeedback()
                    showEditView = true
                },
                .destructive(Text("削除")) {
                    generateHapticFeedback()
                    showDeleteAlert = true
                },
                .cancel(Text("キャンセル")) {
                    selectedEditLocation = nil
                }
            ]
        )
    }
    
    private func deleteAlert() -> Alert {
        Alert(
            title: Text("スポットを削除"),
            message: Text("「\(selectedEditLocation?.title ?? "")」を削除しますか？この操作は取り消せません。"),
            primaryButton: .destructive(Text("削除")) {
                if let location = selectedEditLocation,
                   let locationId = location.id {
                    viewModel.deleteLocation(locationId: locationId, oshiId: oshiId)
                    selectedLocationId = nil
                }
                selectedEditLocation = nil
            },
            secondaryButton: .cancel(Text("キャンセル")) {
                selectedEditLocation = nil
            }
        )
    }
    
    // MARK: - Helper Functions
    
    func moveToCurrentLocation() {
        locationManager.startUpdatingLocation()
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if let userLocation = locationManager.userLocation?.coordinate {
            withAnimation(.easeInOut(duration: 0.5)) {
                region.center = userLocation
                region.span = MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
            }
        }
    }
    
    func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func getPinType(for location: EventLocation) -> MapPinView.PinType {
        if let category = location.category as String? {
            switch category {
            case "ライブ会場": return .live
            case "カフェ・飲食店": return .cafe
            case "グッズショップ": return .shop
            case "撮影スポット": return .photo
            case "聖地巡礼": return .sacred
            case "その他": return .other
            default: break
            }
        }
        
        // Fallback to checking title
        if location.title.contains("ライブ") || location.title.contains("コンサート") {
            return .live
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
