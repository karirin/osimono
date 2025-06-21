import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import Shimmer

struct TimelineView: View {
    @StateObject var viewModel = TimelineViewModel()
    @State private var showNewEventView: Bool = false
    @State private var selectedMode: TimelineMode = .week
    @State private var selectedDate: Date = Date()
    @State private var isMonthMode: Bool = false
    @State private var selectedEventID: UUID? = nil
    
    // Colors
    private let brandColor = Color(hex: "3B82F6") // Blue
    private let backgroundColor = Color(UIColor.systemBackground)
    private let cardBackgroundColor = Color(UIColor.secondarySystemBackground)
    private let textColor = Color(UIColor.label)
    private let secondaryTextColor = Color(UIColor.secondaryLabel)
    @State private var showAddOshiForm = false
    @State private var showingOshiAlert = false
    
    var oshiId: String
    
    private var formattedYearMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: selectedDate)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Modern top bar with year/month
                    HStack {
                        Text(formattedYearMonth)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(textColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .overlay(
                                HStack {
                                    
                                    Spacer()
                                    Button(action: {
                                        generateHapticFeedback()
                                        withAnimation {
                                            isMonthMode.toggle()
                                        }
                                    }) {
                                        Image(systemName: isMonthMode ? "list.bullet" : "calendar")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(textColor)
                                            .frame(width: 40, height: 40)
                                            .background(cardBackgroundColor.opacity(0.8))
                                            .clipShape(Circle())
                                    }
                                    .padding(.leading, 8)
                                }
                            )
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Timeline content
                    if !isMonthMode {
                        EnhancedWeekTimelineView(
                            viewModel: viewModel,
                            selectedDate: $selectedDate,
                            selectedEventID: $selectedEventID
                        )
                    } else {
                        EnhancedMonthCalendarView(
                            viewModel: viewModel,
                            selectedDate: $selectedDate,
                            selectedEventID: $selectedEventID
                        )
                    }
                }
                .overlay(
                    VStack(spacing: -5) {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            // NavigationLinkでイベント作成画面に遷移
                            NavigationLink(
                                destination: EnhancedNewEventView(
                                    isPresented: $showNewEventView,
                                    viewModel: viewModel,
                                    initialDate: selectedDate
                                )
                                .navigationBarHidden(true),
                                isActive: $showNewEventView
                            ) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        Circle()
                                            .fill(brandColor)
                                            .shadow(color: brandColor.opacity(0.4), radius: 8, x: 0, y: 4)
                                    )
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                generateHapticFeedback()
                                if oshiId == "default" {
                                    showNewEventView = true
                                } else {
                                    showNewEventView = true
                                }
                            })
                            .padding([.bottom, .trailing], 18)
                            .transition(.scale)
                        }
                    }
                )
            }
            .navigationBarHidden(true)
        }
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
            viewModel.updateCurrentOshi(id: oshiId)
            viewModel.fetchEvents(forOshiId: oshiId)
        }
        .onChange(of: oshiId) { newId in
            viewModel.updateCurrentOshi(id: newId)
        }
        .fullScreenCover(isPresented: $showAddOshiForm) {
            AddOshiView()
        }
    }
}

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
//        TimelineView(oshiId: "C1B81ED5-7388-407A-9302-8DF67A1F55FC")
        TopView()
    }
}
