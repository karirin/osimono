//import SwiftUI
//import Firebase
//import FirebaseAuth
//import FirebaseStorage
//import Shimmer
//
//class TimelineViewModel: ObservableObject {
//    @Published var events: [TimelineView.TimelineEvent] = []
//    private var dbRef: DatabaseReference {
//        let userID = Auth.auth().currentUser?.uid ?? "default"
//        return Database.database().reference().child("timelineEvents").child(userID)
//    }
//    
//    init() {
//        fetchEvents()
//    }
//    
//    func fetchEvents() {
//        dbRef.observe(.value) { snapshot in
//            var newEvents: [TimelineView.TimelineEvent] = []
//            for child in snapshot.children {
//                if let snap = child as? DataSnapshot,
//                   let dict = snap.value as? [String: Any],
//                   let time = dict["time"] as? String,
//                   let title = dict["title"] as? String,
//                   let colorString = dict["color"] as? String {
//                    let imageURL = dict["imageURL"] as? String
//                    let color: Color = {
//                        switch colorString {
//                        case "gray": return .gray
//                        case "blue": return .blue
//                        case "green": return .green
//                        default: return .gray
//                        }
//                    }()
//                    let event = TimelineView.TimelineEvent(time: time, title: title, color: color, image: nil, imageURL: imageURL)
//
//                    newEvents.append(event)
//                }
//            }
//            DispatchQueue.main.async {
//                self.events = newEvents
//            }
//        }
//    }
//    
//    // 変更後の addEvent 関数
//    func addEvent(event: TimelineView.TimelineEvent) {
//        if let image = event.image {
//            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
//            let imageRef = Storage.storage().reference().child("timelineImages/\(UUID().uuidString).jpg")
//            imageRef.putData(imageData, metadata: nil) { metadata, error in
//                if let error = error {
//                    print("画像アップロード失敗: \(error.localizedDescription)")
//                    return
//                }
//                imageRef.downloadURL { url, error in
//                    if let downloadURL = url {
//                        let eventDict: [String: Any] = [
//                            "time": event.time,
//                            "title": event.title,
//                            "color": event.color == .gray ? "gray" : event.color == .blue ? "blue" : event.color == .green ? "green" : "gray",
//                            "imageURL": downloadURL.absoluteString
//                        ]
//                        self.dbRef.childByAutoId().setValue(eventDict)
//                    }
//                }
//            }
//        } else {
//            let eventDict: [String: Any] = [
//                "time": event.time,
//                "title": event.title,
//                "color": event.color == .gray ? "gray" : event.color == .blue ? "blue" : event.color == .green ? "green" : "gray"
//            ]
//            dbRef.childByAutoId().setValue(eventDict)
//        }
//    }
//
//}
//
//enum TimelineMode: String, CaseIterable {
//    case week = "週間"
//    case month = "月間"
//}
//
//struct TimelineView: View {
//    // タイムラインイベントのデータモデル
//    struct TimelineEvent: Identifiable {
//        let id = UUID()
//        let time: String
//        let title: String
//        let color: Color
//        let image: UIImage?  // Firebase に保存した画像URLを保持する
//        let imageURL: String?
//    }
//    
//    // カレンダーのデータ（今回は使用していません）
//    let daysOfWeek = ["日", "月", "火", "水", "木", "金", "土"]
//    let dayNumbers = [30, 1, 2, 3, 4, 5, 6]
//    let currentDayIndex = 1 // 2番目の日 (1) をハイライト
//    @StateObject var viewModel = TimelineViewModel()
//    @State private var showNewEventView: Bool = false
//    @State private var selectedMode: TimelineMode = .week
//    @State private var selectedDate: Date = Date()
//    @State private var isMonthMode: Bool = false
//    
//    // どのイベントがズームされているかを管理
//    @State private var selectedEventID: UUID? = nil
//    private var formattedYearMonth: String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy年M月"
//        formatter.locale = Locale(identifier: "ja_JP")
//        return formatter.string(from: selectedDate)
//    }
//    var body: some View {
//        VStack(spacing: 0) {
//            HStack {
//                Button(action: {
//                    isMonthMode.toggle()
//                }) {
//                    Image(systemName: "calendar")
//                }
//                .padding(.leading).opacity(0)
//                Spacer()
//                Text(formattedYearMonth)
//                    .font(.system(size: 18))
//                Spacer()
//                Button(action: {
//                    isMonthMode.toggle()
//                }) {
//                    Image(systemName: "calendar")
//                }
//                .padding(.trailing)
//            }
//            
//            if !isMonthMode {
//                WeekTimelineView(viewModel: viewModel, selectedDate: $selectedDate, selectedEventID: $selectedEventID)
//            } else {
//                CustomMonthCalendarView(viewModel: viewModel,
//                                                selectedDate: $selectedDate,
//                                                selectedEventID: $selectedEventID)
//            }
//        }
//        .overlay(
//            VStack{
//                Spacer()
//                HStack{
//                    Spacer()
//                    Button(action: {
//                        showNewEventView = true
//                    }) {
//                        Image(systemName: "plus")
//                            .font(.system(size: 30))
//                            .padding(18)
//                            .background(.black).opacity(0.8)
//                            .foregroundColor(Color.white)
//                            .clipShape(Circle())
//                    }
//                    .shadow(radius: 3)
//                    .padding()
//                }
//            }
//        )
//        .fullScreenCover(isPresented: $showNewEventView) {
//            NewEventView(viewModel: viewModel, initialDate: selectedDate)
//        }
//    }
//}
//
//// 新規追加: 1週間の日付を横並びで表示し、選択した日のイベント一覧を表示するビュー
//struct WeekTimelineView: View {
//    @ObservedObject var viewModel: TimelineViewModel
//    @Binding var selectedDate: Date
//    @Binding var selectedEventID: UUID?
//    @State private var isFlag: Bool = false
//    @State private var baseDate: Date
//    @State private var hapticTriggered: Bool = false
//
//    init(viewModel: TimelineViewModel, selectedDate: Binding<Date>, selectedEventID: Binding<UUID?>) {
//        self.viewModel = viewModel
//        self._selectedDate = selectedDate
//        self._selectedEventID = selectedEventID
//        _baseDate = State(initialValue: selectedDate.wrappedValue)
//    }
//
//    
//    // 曜日を取得するフォーマッタ（例: "土", "日", "月"...）
//    private let dayOfWeekFormatter: DateFormatter = {
//        let f = DateFormatter()
//        f.locale = Locale(identifier: "ja_JP")
//        f.dateFormat = "E"   // 曜日（例: 土, 日, 月 ...）
//        return f
//    }()
//    
//    // 日を取得するフォーマッタ（例: "25"）
//    private let dayOfMonthFormatter: DateFormatter = {
//        let f = DateFormatter()
//        f.locale = Locale(identifier: "ja_JP")
//        f.dateFormat = "d"   // 日（例: 25）
//        return f
//    }()
//    
//    // selectedDate の3日前～3日後の計7日間を表示
//    private var weekDates: [Date] {
//        let calendar = Calendar.current
//        guard let startDate = calendar.date(byAdding: .day, value: -3, to: selectedDate) else {
//            return []
//        }
//        return (0..<7).compactMap { dayOffset in
//            calendar.date(byAdding: .day, value: dayOffset, to: startDate)
//        }
//    }
//    
//    private let yearMonthFormatter: DateFormatter = {
//        let f = DateFormatter()
//        f.locale = Locale(identifier: "ja_JP")
//        f.dateFormat = "yyyy年M月"
//        return f
//    }()
//    
//    private func eventCount(for date: Date) -> Int {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy/MM/dd HH:mm"
//        return viewModel.events.filter { event in
//            guard let eventDate = formatter.date(from: event.time) else { return false }
//            return isSameDay(eventDate, date)
//        }.count
//    }
//    
//    private func findNextEventDate(from date: Date, direction: Int) -> Date {
//        let calendar = Calendar.current
//        for offset in 1...365 {
//            if let newDate = calendar.date(byAdding: .day, value: direction * offset, to: date),
//               eventCount(for: newDate) > 0 {
//                return newDate
//            }
//        }
//        return date
//    }
//    
//    var body: some View {
//        VStack {
//            ScrollViewReader { proxy in
//                ScrollView(.horizontal, showsIndicators: false) {
//                    LazyHStack(spacing: 5) {
//                        ForEach(-365...365, id: \.self) { offset in
//                            let date = Calendar.current.date(byAdding: .day, value: offset, to: baseDate)!
//                            let weekday = dayOfWeekFormatter.string(from: date)
//                            let day = dayOfMonthFormatter.string(from: date)
//                            let count = eventCount(for: date)
//                            VStack {
//                                VStack(spacing: 5) {
//                                    // 上段: 曜日
//                                    Text(weekday)
//                                        .font(.system(size: 14))
//                                    
//                                    // 中段: 日付（選択時は丸背景）
//                                    ZStack {
//                                        Circle()
//                                            .fill(isSameDay(date, selectedDate) ? Color.black : Color.clear)
//                                            .frame(width: 36, height: 36)
//                                        Text(day)
//                                            .font(.system(size: 16))
//                                            .foregroundColor(isSameDay(date, selectedDate) ? .white : .black)
//                                    }
//                                    .frame(height: 40)
//                                    
//                                    if count > 0 {
//                                        // イベント数に応じて最大3つまでドットを表示
//                                        HStack(spacing: 2) {
//                                            ForEach(0..<min(count, 3), id: \.self) { _ in
//                                                Circle()
//                                                    .fill(Color.black)
//                                                    .frame(width: 6, height: 6)
//                                            }
//                                        }
//                                        .frame(height: 10)
//                                    } else {
//                                        // ドットがない場合でも高さを確保
//                                        Spacer()
//                                            .frame(height: 10)
//                                    }
//                                }
//                                .padding(.horizontal, 8)
//                                .onTapGesture {
//                                    selectedDate = date
//                                }
//                            }
//                            .id(offset) // 各セルにIDを付与
//                        }
//                    }
//                }
//                .frame(height: 90)
//                .onAppear {
//                    let offset = Calendar.current.dateComponents([.day], from: baseDate, to: selectedDate).day ?? 0
//                    proxy.scrollTo(offset, anchor: .center)
//                }
//                .onChange(of: selectedDate) { newValue in
//                    let offset = Calendar.current.dateComponents([.day], from: baseDate, to: newValue).day ?? 0
//                    withAnimation {
//                        proxy.scrollTo(offset, anchor: .center)
//                    }
//                }
//            }
//            
//            // 2) 選択した日付のイベント一覧を表示
//
//                if isFlag {
//                    ForEach(eventsForSelectedDate, id: \.id) { event in
//                    }
//                    VStack(spacing: 10){
//                        Spacer()
//                        Image("タイムライン")
//                            .resizable()
//                            .scaledToFit()
//                            .frame(width: 150)
//                            .opacity(0.2)
//                        Text("タイムラインがありません")
//                            .foregroundColor(.gray)
//                            .font(.system(size: 20))
//                        Spacer()
//                        Spacer()
//                    }.frame(width: .infinity,height: .infinity )
//                } else {
//                    ScrollView {
//                    VStack(spacing: 0) {
//                        // ZStackを使用して連続する垂直線を描画
//                        ZStack(alignment: .leading) {
//                            // 背景の連続垂直線
//                            Rectangle()
//                                .fill(Color.gray)
//                                .frame(width: 1)
//                                .offset(x: 68)
//                            VStack{
//                                ForEach(eventsForSelectedDate, id: \.id) { event in
//                                    TimelineRow(event: event, selectedEventID: $selectedEventID)
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//        }
//        .gesture(
//            DragGesture()
//                .onChanged { value in
//                    if !hapticTriggered {
//                        let generator = UIImpactFeedbackGenerator(style: .medium)
//                        generateHapticFeedback()
//                        hapticTriggered = true
//                    }
//                }
//                .onEnded { value in
//                    hapticTriggered = false
//                    let threshold: CGFloat = 50  // スワイプ感知の閾値（必要に応じて調整）
//                    if value.translation.width < -threshold {
//                        // 左スワイプ → 次のイベントがある日へ移動
//                        let newDate = findNextEventDate(from: selectedDate, direction: 1)
//                        withAnimation {
//                            selectedDate = newDate
//                        }
//                    } else if value.translation.width > threshold {
//                        // 右スワイプ → 前のイベントがある日へ移動
//                        let newDate = findNextEventDate(from: selectedDate, direction: -1)
//                        withAnimation {
//                            selectedDate = newDate
//                        }
//                    }
//                }
//        )
////        .gesture(
////            DragGesture()
////                .onEnded { value in
////                    let threshold: CGFloat = 50  // スワイプ感知の閾値（必要に応じて調整）
////                    if value.translation.width < -threshold {
////                        // 左スワイプ → 次のイベントがある日へ移動
////                        let newDate = findNextEventDate(from: selectedDate, direction: 1)
////                        withAnimation {
////                            selectedDate = newDate
////                        }
////                    } else if value.translation.width > threshold {
////                        // 右スワイプ → 前のイベントがある日へ移動
////                        let newDate = findNextEventDate(from: selectedDate, direction: -1)
////                        withAnimation {
////                            selectedDate = newDate
////                        }
////                    }
////                }
////        )
//    }
//
//    // 選択した日付と同じ日のイベントのみを抽出
//    private var eventsForSelectedDate: [TimelineView.TimelineEvent] {
//        let events = viewModel.events.filter { event in
//            guard let date = dateFromString(event.time) else { return false }
//            return isSameDay(date, selectedDate)
//        }
//        DispatchQueue.main.async {
//            print("eventsForSelectedDate2")
//            self.isFlag = events.isEmpty // イベントが存在しない時に true にする
//        }
//        return events
//    }
//    
//    // 日付文字列 -> Date に変換するヘルパー
//    private func dateFromString(_ str: String) -> Date? {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy/MM/dd HH:mm"
//        return formatter.date(from: str)
//    }
//    
//    // 同じ日かどうかを判定するヘルパー
//    private func isSameDay(_ d1: Date, _ d2: Date) -> Bool {
//        let cal = Calendar.current
//        return cal.component(.year, from: d1) == cal.component(.year, from: d2)
//            && cal.component(.month, from: d1) == cal.component(.month, from: d2)
//            && cal.component(.day, from: d1) == cal.component(.day, from: d2)
//    }
//}
//
//struct CustomMonthCalendarView: View {
//    @ObservedObject var viewModel: TimelineViewModel
//    @Binding var selectedDate: Date
//    @Binding var selectedEventID: UUID?
//    @State var isFlag: Bool = false
//    
//    // 表示する年月
//    private var displayYear: Int {
//        Calendar.current.component(.year, from: selectedDate)
//    }
//    private var displayMonth: Int {
//        Calendar.current.component(.month, from: selectedDate)
//    }
//    
//    // 月初日
//    private var firstOfMonth: Date {
//        let components = DateComponents(year: displayYear, month: displayMonth, day: 1)
//        return Calendar.current.date(from: components) ?? Date()
//    }
//    
//    // 月末日
//    private var lastOfMonth: Date {
//        var comps = DateComponents()
//        comps.month = 1
//        comps.day = -1
//        return Calendar.current.date(byAdding: comps, to: firstOfMonth) ?? Date()
//    }
//    
//    // 月の日数
//    private var daysInMonth: Int {
//        Calendar.current.component(.day, from: lastOfMonth)
//    }
//    
//    // 月の初日が週の何曜日か（0=日曜, 1=月曜, ...）
//    private var firstWeekday: Int {
//        Calendar.current.component(.weekday, from: firstOfMonth) - 1
//    }
//    
//    var body: some View {
//        VStack {
//            // 年月タイトル
////            Text("\(displayYear)年\(displayMonth)月")
////                .font(.system(size: 18))
//            
//            // 曜日ヘッダー
//            HStack {
//                ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { wday in
//                    Text(wday)
//                        .font(.subheadline)
//                        .frame(maxWidth: .infinity)
//                }
//            }
//            .padding(.vertical, 4)
//            
//            // 日付グリッド
//            let totalCells = firstWeekday + daysInMonth
//            let rows = Int(ceil(Double(totalCells) / 7.0))
//            
//            VStack(spacing: 8) {
//                ForEach(0..<rows, id: \.self) { rowIndex in
//                    HStack(spacing: 8) {
//                        ForEach(0..<7, id: \.self) { colIndex in
//                            let cellIndex = rowIndex * 7 + colIndex
//                            if cellIndex < firstWeekday || cellIndex >= firstWeekday + daysInMonth {
//                                Spacer()
//                                    .frame(maxWidth: .infinity, maxHeight: 40)
//                            } else {
//                                let day = cellIndex - firstWeekday + 1
//                                let cellDate = makeDate(year: displayYear, month: displayMonth, day: day)
//                                CalendarDayCell(
//                                    date: cellDate,
//                                    selectedDate: $selectedDate,
//                                    events: viewModel.events,
//                                    onTap: { tappedDate in
//                                        selectedDate = tappedDate
//                                    }
//                                )
//                            }
//                        }
//                    }
//                }
//            }
//            
//            // 選択した日のイベント一覧表示
//
//                if isFlag {
//                    
//                    VStack(spacing: 10){
//                        Spacer()
//                        Image("タイムライン")
//                            .resizable()
//                            .scaledToFit()
//                            .frame(width: 150)
//                            .opacity(0.2)
//                        Text("タイムラインがありません")
//                            .foregroundColor(.gray)
//                            .font(.system(size: 20))
//                        Spacer()
//                        Spacer()
//                    }.frame(width: .infinity,height: .infinity )
//                    ForEach(eventsForSelectedDate, id: \.id) { event in
//                    }
//                } else {
//                    
//                    ScrollView {
//                    VStack(spacing: 0) {
//                        ZStack(alignment: .leading) {
//                            Rectangle()
//                                .fill(Color.gray)
//                                .frame(width: 1)
//                                .offset(x: 68)
//                            VStack {
//                                ForEach(eventsForSelectedDate, id: \.id) { event in
//                                    TimelineRow(event: event, selectedEventID: $selectedEventID)
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//        }
//        .padding()
//        // ここでスワイプジェスチャーを追加
//        .gesture(
//            DragGesture(minimumDistance: 50)
//                .onEnded { value in
//                    if abs(value.translation.width) > abs(value.translation.height) {
//                        if value.translation.width < 0 {
//                            // 左スワイプ：次の月
//                            if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) {
//                                selectedDate = nextMonth
//                            }
//                        } else {
//                            // 右スワイプ：前の月
//                            if let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) {
//                                selectedDate = prevMonth
//                            }
//                        }
//                    }
//                }
//        )
//    }
//    
//    private var eventsForSelectedDate: [TimelineView.TimelineEvent] {
//        let events = viewModel.events.filter { event in
//            print("eventsForSelectedDate1")
//            guard let date = dateFromString(event.time) else { return false }
//            return isSameDay(date, selectedDate)
//        }
//        DispatchQueue.main.async {
//            print("eventsForSelectedDate2")
//            self.isFlag = events.isEmpty // イベントが存在しない時に true にする
//        }
//        print("eventsForSelectedDate3")
//        return events
//    }
//    
//    private func makeDate(year: Int, month: Int, day: Int) -> Date {
//        let comps = DateComponents(year: year, month: month, day: day)
//        return Calendar.current.date(from: comps) ?? Date()
//    }
//    
//    private func dateFromString(_ str: String) -> Date? {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy/MM/dd HH:mm"
//        return formatter.date(from: str)
//    }
//    
//    private func isSameDay(_ d1: Date, _ d2: Date) -> Bool {
//        let cal = Calendar.current
//        return cal.component(.year, from: d1) == cal.component(.year, from: d2)
//            && cal.component(.month, from: d1) == cal.component(.month, from: d2)
//            && cal.component(.day, from: d1) == cal.component(.day, from: d2)
//    }
//}
//
//// 日付セルを表示するカスタムView
//fileprivate struct CalendarDayCell: View {
//    let date: Date
//    @Binding var selectedDate: Date
//    let events: [TimelineView.TimelineEvent]
//    let onTap: (Date) -> Void
//    
//    private var dayNumber: Int {
//        Calendar.current.component(.day, from: date)
//    }
//    
//    // イベント数（同日）
//    private var eventCount: Int {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy/MM/dd HH:mm"
//        return events.filter { event in
//            guard let eDate = formatter.date(from: event.time) else { return false }
//            return isSameDay(eDate, date)
//        }.count
//    }
//    
//    var body: some View {
//        VStack(spacing: 2) {
//            // 選択中の日付なら丸背景などでハイライト
//            ZStack {
//                if isSameDay(date, selectedDate) {
//                    Circle()
//                        .fill(Color.black)
//                        .frame(width: 28, height: 28)
//                    Text("\(dayNumber)")
//                        .foregroundColor(.white)
//                } else {
//                    Text("\(dayNumber)")
//                        .foregroundColor(.primary)
//                }
//            }
//            // ドット表示（最大3つまで）
//            if eventCount > 0 {
//                HStack(spacing: 2) {
//                    ForEach(0..<min(eventCount, 3), id: \.self) { _ in
//                        Circle()
//                            .fill(Color.black)
//                            .frame(width: 6, height: 6)
//                    }
//                }
//            } else {
//                // イベントが0件でも高さを合わせたい場合は Spacer などで調整
//                Spacer().frame(height: 4)
//            }
//        }
//        .frame(maxWidth: .infinity, minHeight: 40)
//        .onTapGesture {
//            onTap(date)
//        }
//    }
//    
//    private func isSameDay(_ d1: Date, _ d2: Date) -> Bool {
//        let cal = Calendar.current
//        return cal.component(.year, from: d1) == cal.component(.year, from: d2)
//            && cal.component(.month, from: d1) == cal.component(.month, from: d2)
//            && cal.component(.day, from: d1) == cal.component(.day, from: d2)
//    }
//}
//
//// タイムラインの各行を表示するサブビュー（ズームアニメーション付き）
//// 変更後（画像表示を追加）
//struct TimelineRow: View {
//    let event: TimelineView.TimelineEvent
//    @Binding var selectedEventID: UUID?
//    var formattedTime: String {
//        let inputFormatter = DateFormatter()
//        inputFormatter.dateFormat = "yyyy/MM/dd HH:mm" // 保存時のフォーマットに合わせる
//        if let date = inputFormatter.date(from: event.time) {
//            let outputFormatter = DateFormatter()
//            outputFormatter.dateFormat = "HH:mm" // 時:分のみ表示
//            return outputFormatter.string(from: date)
//        } else {
//            return event.time
//        }
//    }
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 8) {
//            HStack(alignment: .center, spacing: 0) {
//                VStack {
//                    // ステータスドット
//                    Circle()
//                        .fill(event.color)
//                        .frame(width: 12, height: 12)
//                        .opacity(selectedEventID == event.id ? 1 : 0)
//                    // 時刻表示
//                    Text(formattedTime)
//                        .font(.system(size: 18))
//                        .foregroundColor(.gray)
//                        .frame(width: 55, alignment: .trailing)
//                        .padding(.trailing, 8)
//                }
//                
//                // ステータスドット
//                Circle()
//                    .fill(event.color)
//                    .frame(width: 12, height: 12)
//                    .opacity(selectedEventID != event.id ? 1 : 0)
//                // タイトル表示
//                VStack{
//                    HStack(alignment: .center, spacing: 0) {
//                        Text(event.title)
//                            .font(.system(size: 18))
//                            .padding(.leading, 8)
//                        Spacer()
//                        if selectedEventID != event.id,let imageURL = event.imageURL, let url = URL(string: imageURL) {
//                            Image(systemName: "photo").padding(.trailing)
//                        }
//                    }
//                    if selectedEventID == event.id, let imageURL = event.imageURL, let url = URL(string: imageURL) {
//                        AsyncImage(url: url) { phase in
//                            switch phase {
//                            case .empty:
//                                Rectangle()
//                                    .frame(width: 150, height: 150)
//                                    .foregroundColor(.gray)
//                                    .cornerRadius(10)
//                                    .shimmer(true)
//                            case .success(let image):
//                                image.resizable()
//                                    .scaledToFit()
//                                    .frame(maxWidth: 150, maxHeight: 150)
//                                    .cornerRadius(10)
//                            case .failure:
//                                Image(systemName: "photo")
//                            @unknown default:
//                                EmptyView()
//                            }
//                        }
//                        .transition(.opacity)
//                        .animation(.easeInOut(duration: 0.2), value: selectedEventID)
//                    }
//                }
//                .padding(.vertical, 12)
//                .background(Color(UIColor.secondarySystemBackground))
//                .cornerRadius(4)
//                .padding(.horizontal, 8)
//                .padding(.vertical, 2)
//                .scaleEffect(selectedEventID == event.id ? 1.15 : 1.0)
//                .animation(.easeInOut(duration: 0.2), value: selectedEventID)
//            }
//            .onTapGesture {
//                if selectedEventID == event.id {
//                    selectedEventID = nil
//                } else {
//                    selectedEventID = event.id
//                }
//            }
//        }
//    }
//}
//
//struct NewEventView: View {
//    @State private var eventTitle = ""
//    @State private var startDate = Date()
//    @State private var endDate = Date().addingTimeInterval(3600)
//    @State private var eventDescription = ""
//    
//    @State private var newGoodsName = ""
//    @State private var newPrice = ""
//    @State private var newPurchasePlace = ""
//    @State private var newCategory = ""
//    @State private var newOshi = ""
//    @State private var newMemo = ""
//    
//    @State private var eventDate: Date
//    @State private var title: String = ""
//    @State private var isOshiActivity: Bool = true
//    @State private var showDatePicker = false
//    @State private var showImagePicker: Bool = false
//    @ObservedObject var viewModel: TimelineViewModel
//    @State private var privacy = "公開"
//    @State private var selectedImage: UIImage?
//    @State private var isShowingImagePicker = false
//    @FocusState private var isTitleFocused: Bool
//    @Environment(\.presentationMode) var presentationMode
//    @State private var isShowingGoodsList = false
//    @State private var isImageHovering = false
//    
//    // Color theme
//    private let accentColor = Color.blue
//    private let backgroundColor = Color(UIColor.systemBackground)
//    private let secondaryBackgroundColor = Color(UIColor.secondarySystemBackground)
//    private let textColor = Color(UIColor.label)
//    private let secondaryTextColor = Color(UIColor.secondaryLabel)
//    
//    init(viewModel: TimelineViewModel, initialDate: Date) {
//        self.viewModel = viewModel
//        _eventDate = State(initialValue: initialDate)
//    }
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Modern header with drop shadow
//            headerView
//                .background(backgroundColor)
//                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
//            
//            ScrollView(showsIndicators: false) {
//                VStack(spacing: 20) {
//                    // Enhanced image picker
//                    imagePickerView
//                        .padding(.horizontal, 16)
//                        .padding(.top, 20)
//                    
//                    // Styled title field
//                    titleFieldView
//                        .padding(.horizontal, 16)
//                    
//                    // Date picker with improved styling
//                    datePickerView
//                        .padding(.horizontal, 16)
//                    
//                    // Toggle with better visual styling
//                    activityToggleView
//                        .padding(.horizontal, 16)
//                    
//                    // Previous posts selection button
//                    previousPostsButton
//                        .padding(.vertical, 12)
//                    
//                    Spacer(minLength: 30)
//                }
//            }
//            .background(backgroundColor)
//        }
//        .sheet(isPresented: $isShowingImagePicker) {
//            ImageTimeLinePicker(selectedImage: $selectedImage)
//        }
//        .sheet(isPresented: $isShowingGoodsList) {
//            previousPostsSheet
//        }
//        .onAppear {
//            isTitleFocused = true
//        }
//    }
//    
//    // MARK: - UI Components
//    
//    private var headerView: some View {
//        HStack(spacing: 16) {
//            Button(action: {
//                self.presentationMode.wrappedValue.dismiss()
//            }) {
//                Image(systemName: "xmark")
//                    .font(.system(size: 17, weight: .medium))
//                    .foregroundStyle(textColor)
//                    .frame(width: 38, height: 38)
//                    .background(secondaryBackgroundColor)
//                    .clipShape(Circle())
//            }
//            
//            Spacer()
//            
//            Text("タイムライン作成")
//                .font(.system(size: 18, weight: .semibold))
//                .foregroundColor(textColor)
//            
//            Spacer()
//            
//            Button(action: {
//                let color: Color = isOshiActivity ? .gray : accentColor
//                let dateFormatter = DateFormatter()
//                dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
//                let timeString = dateFormatter.string(from: eventDate)
//                let newEvent = TimelineView.TimelineEvent(
//                    time: timeString,
//                    title: title,
//                    color: color,
//                    image: selectedImage,
//                    imageURL: nil
//                )
//                viewModel.addEvent(event: newEvent)
//                presentationMode.wrappedValue.dismiss()
//            }) {
//                Text("作成")
//                    .font(.system(size: 17, weight: .medium))
//                    .foregroundColor(!title.isEmpty ? accentColor : secondaryTextColor)
//            }
//            .disabled(title.isEmpty)
//        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 16)
//    }
//    
//    private var imagePickerView: some View {
//        Button(action: {
//            isShowingImagePicker = true
//        }) {
//            ZStack {
//                if let image = selectedImage {
//                    // Selected image view
//                    Image(uiImage: image)
//                        .resizable()
//                        .scaledToFill()
//                        .frame(height: 220)
//                        .frame(maxWidth: .infinity)
//                        .clipShape(RoundedRectangle(cornerRadius: 20))
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 20)
//                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
//                        )
//                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
//                        .overlay(
//                            imageOverlayButton
//                        )
//                } else {
//                    // Empty image view
//                    ZStack {
//                        RoundedRectangle(cornerRadius: 20)
//                            .fill(secondaryBackgroundColor)
//                            .frame(height: 220)
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 20)
//                                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
//                            )
//                            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
//                        
//                        VStack(spacing: 14) {
//                            Image(systemName: "photo.on.rectangle.angled")
//                                .font(.system(size: 42))
//                                .foregroundStyle(secondaryTextColor)
//                            
//                            Text("タップして画像を追加")
//                                .font(.system(size: 16, weight: .medium))
//                                .foregroundColor(secondaryTextColor)
//                        }
//                    }
//                    .scaleEffect(isImageHovering ? 1.01 : 1.0)
//                    .animation(.spring(response: 0.3), value: isImageHovering)
//                    .onHover { hovering in
//                        isImageHovering = hovering
//                    }
//                }
//            }
//        }
//    }
//    
//    private var imageOverlayButton: some View {
//        VStack {
//            Spacer()
//            HStack {
//                Spacer()
//                Button(action: {
//                    isShowingImagePicker = true
//                }) {
//                    HStack(spacing: 6) {
//                        Image(systemName: "photo")
//                            .font(.system(size: 14))
//                        Text("画像を変更")
//                            .font(.system(size: 14, weight: .medium))
//                    }
//                    .padding(.vertical, 8)
//                    .padding(.horizontal, 14)
//                    .background(
//                        Capsule()
//                            .fill(Color.black.opacity(0.7))
//                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
//                    )
//                    .foregroundColor(.white)
//                }
//                .padding(16)
//            }
//        }
//    }
//    
//    private var titleFieldView: some View {
//        VStack(alignment: .leading, spacing: 10) {
//            HStack {
//                Text("タイトル")
//                    .font(.system(size: 16, weight: .medium))
//                    .foregroundColor(textColor)
//                
//                Spacer()
//                
//                Text("\(title.count) / 48")
//                    .font(.system(size: 14))
//                    .foregroundColor(secondaryTextColor)
//            }
//            
//            TextField("ライブ、イベント名など", text: $title)
//                .font(.system(size: 16))
//                .padding(.horizontal, 16)
//                .padding(.vertical, 14)
//                .background(
//                    RoundedRectangle(cornerRadius: 12)
//                        .fill(secondaryBackgroundColor)
//                )
//                .overlay(
//                    RoundedRectangle(cornerRadius: 12)
//                        .stroke(title.isEmpty ? Color.clear : accentColor.opacity(0.3), lineWidth: 1.5)
//                )
//                .focused($isTitleFocused)
//        }
//    }
//    
//    private var datePickerView: some View {
//        VStack(spacing: 10) {
//            HStack {
//                Text("日付を指定")
//                    .font(.system(size: 16, weight: .medium))
//                    .foregroundColor(textColor)
//                
//                Spacer()
//                    DatePickerTextField(date: $eventDate, placeholder: "日付と時間を指定")
//                        .frame(height: 44)
//                        .padding(.trailing)
//                        .background(
//                            HStack{
//                                Spacer()
//                            RoundedRectangle(cornerRadius: 12)
//                                .fill(secondaryBackgroundColor)
//                                .frame(width: 190)
//                            }
//                        )
//                }
//        }
//    }
//    
//    private var activityToggleView: some View {
//        HStack {
//            VStack(alignment: .leading, spacing: 4) {
//                Text(isOshiActivity ? "推しの活動" : "自分の活動")
//                    .font(.system(size: 16, weight: .medium))
//                    .foregroundColor(textColor)
//                
//                if isOshiActivity {
//                    Text("推し活のイベントとしてタイムラインに表示")
//                        .font(.system(size: 13))
//                        .foregroundColor(secondaryTextColor)
//                } else {
//                    Text("あなた自身の活動としてタイムラインに表示")
//                        .font(.system(size: 13))
//                        .foregroundColor(secondaryTextColor)
//                }
//            }
//            
//            Spacer()
//            
//            Toggle("", isOn: $isOshiActivity)
//                .toggleStyle(SwitchToggleStyle(tint: accentColor))
//                .labelsHidden()
//        }
//        .padding(16)
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(secondaryBackgroundColor)
//        )
//    }
//    
//    private var previousPostsButton: some View {
//        Button(action: {
//            isShowingGoodsList.toggle()
//        }) {
//            HStack(spacing: 12) {
//                if isShowingGoodsList {
//                    Image(systemName: "xmark.circle.fill")
//                        .font(.system(size: 18))
//                    Text("閉じる")
//                        .font(.system(size: 16, weight: .medium))
//                } else {
//                    Image(systemName: "clock.arrow.circlepath")
//                        .font(.system(size: 18))
//                    Text("過去の投稿から選択")
//                        .font(.system(size: 16, weight: .medium))
//                }
//            }
//            .foregroundColor(accentColor)
//            .padding(.vertical, 12)
//            .padding(.horizontal, 20)
//            .background(
//                Capsule()
//                    .fill(accentColor.opacity(0.1))
//            )
//        }
//    }
//    
//    private var previousPostsSheet: some View {
//        VStack {
//            HStack {
//                Button(action: {
//                    isShowingGoodsList = false
//                }) {
//                    Image(systemName: "xmark")
//                        .font(.system(size: 17, weight: .medium))
//                        .foregroundStyle(textColor)
//                        .frame(width: 36, height: 36)
//                        .background(secondaryBackgroundColor)
//                        .clipShape(Circle())
//                }
//                
//                Spacer()
//                
//                Text("過去の投稿")
//                    .font(.system(size: 18, weight: .semibold))
//                
//                Spacer()
//                
//                Color.clear
//                    .frame(width: 36, height: 36)
//            }
//            .padding()
//            
//            SelectGoodsListView(flag: $isShowingGoodsList, onGoodsSelected: { goods in
//                title = goods.title!
//                let formatter = DateFormatter()
//                formatter.dateFormat = "yyyy/MM/dd, HH:mm"
//                if let goodsDate = formatter.date(from: goods.date!) {
//                    eventDate = goodsDate
//                }
//                if !goods.imageUrl!.isEmpty, let url = URL(string: goods.imageUrl!) {
//                    loadImage(url: url)
//                } else {
//                    selectedImage = nil
//                }
//            })
//        }
//    }
//    
//    // MARK: - Helper Functions
//    
//    private func loadImage(url: URL) {
//        URLSession.shared.dataTask(with: url) { data, _, _ in
//            guard let data = data, let image = UIImage(data: data) else { return }
//            DispatchQueue.main.async {
//                self.selectedImage = image
//            }
//        }.resume()
//    }
//    
//    func saveEvent() {
//        guard let userId = Auth.auth().currentUser?.uid else { return }
//        
//        if let image = selectedImage {
//            uploadImage(userId: userId) { imageUrl in
//                saveEventToDatabase(userId: userId, imageUrl: imageUrl)
//            }
//        } else {
//            saveEventToDatabase(userId: userId, imageUrl: nil)
//        }
//    }
//    
//    func uploadImage(userId: String, completion: @escaping (String?) -> Void) {
//        guard let image = selectedImage else {
//            completion(nil)
//            return
//        }
//        
//        let storageRef = Storage.storage().reference()
//        let imageID = UUID().uuidString
//        let imageRef = storageRef.child("events/\(userId)/\(imageID).jpg")
//        
//        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
//            completion(nil)
//            return
//        }
//        
//        let metadata = StorageMetadata()
//        metadata.contentType = "image/jpeg"
//        
//        imageRef.putData(imageData, metadata: metadata) { _, error in
//            if let error = error {
//                print("アップロードエラー: \(error.localizedDescription)")
//                completion(nil)
//                return
//            }
//            
//            imageRef.downloadURL { url, error in
//                if let error = error {
//                    print("画像URL取得エラー: \(error.localizedDescription)")
//                    completion(nil)
//                    return
//                }
//                
//                completion(url?.absoluteString)
//            }
//        }
//    }
//    
//    func saveEventToDatabase(userId: String, imageUrl: String?) {
//        let ref = Database.database().reference().child("events").child(userId)
//        let newEventID = ref.childByAutoId().key ?? UUID().uuidString
//        
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
//        
//        let event = [
//            "id": newEventID,
//            "userId": userId,
//            "title": eventTitle,
//            "imageUrl": imageUrl ?? "",
//            "startDate": dateFormatter.string(from: startDate),
//            "endDate": dateFormatter.string(from: endDate),
//            "description": eventDescription,
//            "privacy": privacy,
//            "createdAt": ServerValue.timestamp()
//        ] as [String : Any]
//        
//        ref.child(newEventID).setValue(event) { error, _ in
//            if let error = error {
//                print("イベント保存エラー: \(error.localizedDescription)")
//            } else {
//                print("イベントを保存しました: \(newEventID)")
//            }
//        }
//    }
//}
//
//struct SelectGoodsListView: View {
//    @State private var goods: [Goods] = []
//    @State private var selectedImage: UIImage?
//    @State private var isShowingForm = false
//    @State private var newGoodsName = ""
//    @State private var newPrice = ""
//    @State private var newPurchasePlace = ""
//    @State private var newCategory = ""
//    @State private var newOshi = ""
//    @State private var newMemo = ""
//    @State private var newStatus = "所持中"
//    @State private var newFavorite = 3
//    @Binding var flag: Bool
//    var onGoodsSelected: ((Goods) -> Void)? = nil
//    @State var isLoading = false
//    
//    var userId: String? {
//        Auth.auth().currentUser?.uid
//    }
//    
//    var body: some View {
//        VStack{
//            if isLoading {
//                VStack{
//                    Spacer()
//                }.frame(width: .infinity,height: .infinity )
//            } else if goods.isEmpty {
//                VStack(spacing: 10){
//                    Spacer()
//                    Image("エンプティステート")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 150)
//                        .opacity(0.2)
//                    Text("投稿がありません")
//                        .foregroundColor(.gray)
//                        .font(.system(size: 20))
//                    Spacer()
//                    Spacer()
//                }.frame(width: .infinity,height: .infinity )
//            } else {
//                ScrollView {
//                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
//                        ForEach(goods) { item in
//                            Button(action: {
//                                onGoodsSelected?(item)
//                                flag = false
//                            }) {
//                                ZStack(alignment: .bottomLeading) {
//                                    if !item.imageUrl!.isEmpty, let url = URL(string: item.imageUrl!) {
//                                        AsyncImage(url: url) { image in
//                                            image
//                                                .resizable()
//                                                .scaledToFill()
//                                                .frame(width: UIScreen.main.bounds.width / 3 - 2,
//                                                       height: UIScreen.main.bounds.width / 3 - 2)
//                                        } placeholder: {
//                                            Rectangle()
//                                                .foregroundColor(.gray)
//                                                .frame(width: UIScreen.main.bounds.width / 3 - 2,
//                                                       height: UIScreen.main.bounds.width / 3 - 2)
//                                                .shimmer(true)
//                                        }
//                                    } else {
//                                        ZStack{
//                                            Rectangle()
//                                                .foregroundColor(.gray).opacity(0.3)
//                                                .frame(width: UIScreen.main.bounds.width / 3 - 2,
//                                                       height: UIScreen.main.bounds.width / 3 - 2)
//                                            VStack{
//                                                Image(systemName: "photo")
//                                                    .font(.system(size: 30))
//                                                    .foregroundStyle(Color.black)
//                                                Text("画像がありません")
//                                                    .bold()
//                                                    .font(.system(size: 14))
//                                                    .foregroundStyle(Color.black)
//                                            }
//                                        }
//                                    }
//                                    if let name = item.title, !name.isEmpty {
//                                        Text(name)
//                                            .foregroundColor(.white)
//                                            .padding(4)
//                                            .background(Color.black.opacity(0.7))
//                                            .clipShape(RoundedRectangle(cornerRadius: 5))
//                                            .offset(x: 5, y: -10)
//                                    }
//                                }
//                                .cornerRadius(10)
//                            }
//                        }
//                    }
//                }
//            }
//        }
//        .onAppear {
////            addTestData()
//            fetchGoods()
//        }
//    }
//    
//    func addTestData() {
//        let testImages = [
//            "https://via.placeholder.com/120/FF0000/FFFFFF?text=推し活1",
//            "https://via.placeholder.com/120/00FF00/FFFFFF?text=推し活2",
//            "https://via.placeholder.com/120/0000FF/FFFFFF?text=推し活3",
//            "https://via.placeholder.com/120/FFFF00/FFFFFF?text=推し活4",
//            "https://via.placeholder.com/120/FF00FF/FFFFFF?text=推し活5",
//            "https://via.placeholder.com/120/00FFFF/FFFFFF?text=推し活6",
//            "https://via.placeholder.com/120/AAAAAA/FFFFFF?text=推し活7"
//        ]
//        
//        let testGoods = testImages.enumerated().map { index, url in
//            Goods(
//                id: UUID().uuidString,
//                userId: userId ?? "testUser",
//                imageUrl: url,
//                date: "2025-03-20",
//                price: (index + 1) * 1000,
//                purchasePlace: "公式ストア",
//                category: "アクリル",
//                memo: "テストデータ",
//                status: "所持中",
//                favorite: (index % 5) + 1
//            )
//        }
//        
//        self.goods = testGoods
//    }
//    /// ✅ Realtime Database からデータを取得
//    func fetchGoods() {
//        guard let userId = userId else { return }
//        self.isLoading = true
//        let ref = Database.database().reference().child("goods").child(userId)
//        ref.observeSingleEvent(of: .value) { snapshot in
//            var newGoods: [Goods] = []
//            
//            for child in snapshot.children {
//                if let childSnapshot = child as? DataSnapshot {
//                    
//                    if let value = childSnapshot.value as? [String: Any] {
//                        do {
//                            let jsonData = try JSONSerialization.data(withJSONObject: value)
//                            let good = try JSONDecoder().decode(Goods.self, from: jsonData)
//                            newGoods.append(good)
//                        } catch {
//                            print("デコードエラー: \(error.localizedDescription)")
//                            print("エラーが発生したデータ: \(value)")
//                        }
//                    }
//                }
//            }
//            
//            DispatchQueue.main.async {
//                self.goods = newGoods
//                self.isLoading = false
//                print("fetchGoods 完了", self.goods)
//            }
//        }
//    }
//}
//
//// 追加: UIDatePicker を inputView として使うための UIViewRepresentable
//struct DatePickerTextField: UIViewRepresentable {
//    @Binding var date: Date
//    var placeholder: String
//    
//    // 表示用フォーマッタ（お好みで調整可能）
//    private let dateFormatter: DateFormatter = {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        formatter.locale = Locale(identifier: "ja_JP")
//        return formatter
//    }()
//    
//    func makeUIView(context: Context) -> UITextField {
//        let textField = NoCaretTextField(frame: .zero)
//        textField.placeholder = placeholder
//        textField.inputView = context.coordinator.datePicker
//        textField.inputAccessoryView = context.coordinator.toolbar
//        textField.delegate = context.coordinator
//        textField.textAlignment = .right
//        textField.font = UIFont.systemFont(ofSize: 20)
//        return textField
//    }
//    
//    func updateUIView(_ uiView: UITextField, context: Context) {
//        // 日付が更新されたらテキストも更新
//        uiView.text = dateFormatter.string(from: date)
//    }
//    
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self, dateFormatter: dateFormatter)
//    }
//    
//    class Coordinator: NSObject, UITextFieldDelegate {
//        var parent: DatePickerTextField
//        var dateFormatter: DateFormatter
//        
//        // 下部に表示する UIDatePicker
//        let datePicker = UIDatePicker()
//        
//        // キーボード上部に表示するツールバー（完了ボタンなど）
//        lazy var toolbar: UIToolbar = {
//            let tb = UIToolbar()
//            tb.sizeToFit()
//            let doneButton = UIBarButtonItem(title: "完了", style: .done, target: self, action: #selector(doneTapped))
//            let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
//            tb.setItems([flexibleSpace, doneButton], animated: false)
//            return tb
//        }()
//        
//        init(_ parent: DatePickerTextField, dateFormatter: DateFormatter) {
//            self.parent = parent
//            self.dateFormatter = dateFormatter
//            super.init()
//            
//            datePicker.preferredDatePickerStyle = .wheels
//            datePicker.datePickerMode = .dateAndTime
//            datePicker.locale = Locale(identifier: "ja_JP")
//            datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
//        }
//        
//        // 日付が変わったらバインド先の変数を更新
//        @objc func dateChanged() {
//            parent.date = datePicker.date
//        }
//        
//        // Doneボタンでキーボードを閉じる
//        @objc func doneTapped() {
//            parent.date = datePicker.date
//            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
//                                            to: nil, from: nil, for: nil)
//        }
//    }
//}
//
//// 新規追加：ImagePicker.swift として追加可能なコード
//struct ImageTimeLinePicker: UIViewControllerRepresentable {
//    @Environment(\.presentationMode) var presentationMode
//    @Binding var selectedImage: UIImage?
//    
//    func makeUIViewController(context: Context) -> UIImagePickerController {
//        let picker = UIImagePickerController()
//        picker.delegate = context.coordinator
//        return picker
//    }
//    
//    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
//    
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//    
//    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
//        let parent: ImageTimeLinePicker
//        init(_ parent: ImageTimeLinePicker) {
//            self.parent = parent
//        }
//        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//            if let image = info[.originalImage] as? UIImage {
//                parent.selectedImage = image
//            }
//            parent.presentationMode.wrappedValue.dismiss()
//        }
//    }
//}
//
//
//class NoCaretTextField: UITextField {
//    // キャレット（カーソル）を非表示にする
//    override func caretRect(for position: UITextPosition) -> CGRect {
//        return .zero
//    }
//}
//
//// プレビュー
//struct TimelineView_Previews: PreviewProvider {
//    static var previews: some View {
//        TimelineView()
////        NewEventView(viewModel: TimelineViewModel(), initialDate: Date())
////        SelectGoodsListView(flag: .constant(false))
//    }
//}
