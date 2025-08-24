//
//  FilterSheetView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

// View for filtering locations
struct FilterSheetView: View {
    @Binding var selectedCategories: Set<String>
    @Environment(\.presentationMode) var presentationMode
    
    // Localized categories
    private var categories: [String] {
        return [
            NSLocalizedString("live_venue", comment: "Live Venue"),
            NSLocalizedString("pilgrimage", comment: "Pilgrimage"),
            NSLocalizedString("cafe_restaurant", comment: "Cafe・Restaurant"),
            NSLocalizedString("goods_shop", comment: "Goods Shop"),
            NSLocalizedString("photo_spot", comment: "Photo Spot"),
            NSLocalizedString("other", comment: "Other")
        ]
    }
    
    private var categoryColors: [String: Color] {
        let liveVenue = NSLocalizedString("live_venue", comment: "Live Venue")
        let pilgrimage = NSLocalizedString("pilgrimage", comment: "Pilgrimage")
        let cafeRestaurant = NSLocalizedString("cafe_restaurant", comment: "Cafe・Restaurant")
        let goodsShop = NSLocalizedString("goods_shop", comment: "Goods Shop")
        let photoSpot = NSLocalizedString("photo_spot", comment: "Photo Spot")
        let other = NSLocalizedString("other", comment: "Other")
        
        return [
            liveVenue: Color(hex: "6366F1"),
            pilgrimage: Color(hex: "EF4444"),
            cafeRestaurant: Color(hex: "10B981"),
            goodsShop: Color(hex: "F59E0B"),
            photoSpot: Color(hex: "EC4899"),
            other: Color(hex: "6B7280")
        ]
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text(NSLocalizedString("category", comment: "Category"))) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            generateHapticFeedback()
                            if selectedCategories.contains(category) {
                                if selectedCategories.count > 1 {
                                    selectedCategories.remove(category)
                                }
                            } else {
                                selectedCategories.insert(category)
                            }
                        }) {
                            HStack {
                                Circle()
                                    .fill(categoryColors[category, default: .gray])
                                    .frame(width: 12, height: 12)
                                
                                Text(category)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedCategories.contains(category) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(categoryColors[category, default: .blue])
                                }
                            }
                        }
                        .accessibilityLabel(category)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle(NSLocalizedString("filter", comment: "Filter"))
            .navigationBarItems(
                leading: Button(NSLocalizedString("reset", comment: "Reset")) {
                    selectedCategories = Set(categories)
                },
                trailing: Button(NSLocalizedString("close", comment: "Close")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
