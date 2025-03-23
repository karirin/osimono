import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import Shimmer

class TimelineViewModel: ObservableObject {
    @Published var events: [TimelineView.TimelineEvent] = []
    private var dbRef: DatabaseReference {
        let userID = Auth.auth().currentUser?.uid ?? "default"
        return Database.database().reference().child("timelineEvents").child(userID)
    }
    
    init() {
        fetchEvents()
    }
    
    func fetchEvents() {
        dbRef.observe(.value) { snapshot in
            var newEvents: [TimelineView.TimelineEvent] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any],
                   let time = dict["time"] as? String,
                   let title = dict["title"] as? String,
                   let colorString = dict["color"] as? String {
                    let imageURL = dict["imageURL"] as? String
                    let color: Color = {
                        switch colorString {
                        case "gray": return .gray
                        case "blue": return .blue
                        case "green": return .green
                        default: return .gray
                        }
                    }()
                    let event = TimelineView.TimelineEvent(time: time, title: title, color: color, image: nil, imageURL: imageURL)

                    newEvents.append(event)
                }
            }
            DispatchQueue.main.async {
                self.events = newEvents
            }
        }
    }
    
    // 変更後の addEvent 関数
    func addEvent(event: TimelineView.TimelineEvent) {
        if let image = event.image {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
            let imageRef = Storage.storage().reference().child("timelineImages/\(UUID().uuidString).jpg")
            imageRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    print("画像アップロード失敗: \(error.localizedDescription)")
                    return
                }
                imageRef.downloadURL { url, error in
                    if let downloadURL = url {
                        let eventDict: [String: Any] = [
                            "time": event.time,
                            "title": event.title,
                            "color": event.color == .gray ? "gray" : event.color == .blue ? "blue" : event.color == .green ? "green" : "gray",
                            "imageURL": downloadURL.absoluteString
                        ]
                        self.dbRef.childByAutoId().setValue(eventDict)
                    }
                }
            }
        } else {
            let eventDict: [String: Any] = [
                "time": event.time,
                "title": event.title,
                "color": event.color == .gray ? "gray" : event.color == .blue ? "blue" : event.color == .green ? "green" : "gray"
            ]
            dbRef.childByAutoId().setValue(eventDict)
        }
    }

}

enum TimelineMode: String, CaseIterable {
    case week = "週間"
    case month = "月間"
}

struct TimelineView: View {
    // タイムラインイベントのデータモデル
    struct TimelineEvent: Identifiable {
        let id = UUID()
        let time: String
        let title: String
        let color: Color
        let image: UIImage?  // Firebase に保存した画像URLを保持する
        let imageURL: String?
    }
    
    
    // カレンダーのデータ（今回は使用していません）
    let daysOfWeek = ["日", "月", "火", "水", "木", "金", "土"]
    let dayNumbers = [30, 1, 2, 3, 4, 5, 6]
    let currentDayIndex = 1 // 2番目の日 (1) をハイライト
    @StateObject var viewModel = TimelineViewModel()
    @State private var showNewEventView: Bool = false
    @State private var selectedMode: TimelineMode = .week
    @State private var selectedDate: Date = Date()
    @State private var isMonthMode: Bool = false
    
    // どのイベントがズームされているかを管理
    @State private var selectedEventID: UUID? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                
                Spacer()
                Button(action: {
                    isMonthMode.toggle()
                }) {
                    Image(systemName: "calendar")
                }
                .padding(.trailing)
            }
            
            if !isMonthMode {
                // 週間ビュー
                WeekTimelineView(viewModel: viewModel, selectedDate: $selectedDate, selectedEventID: $selectedEventID)
            } else {
                // 月間ビュー
                MonthTimelineView(viewModel: viewModel, selectedDate: $selectedDate, selectedEventID: $selectedEventID)
            }
        }
        .overlay(
            VStack{
                Spacer()
                HStack{
                    Spacer()
                    Button(action: {
                        showNewEventView = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 30))
                            .padding(20)
                            .background(.black).opacity(0.8)
                            .foregroundColor(Color.white)
                            .clipShape(Circle())
                    }
                    .shadow(radius: 3)
                    .padding()
                }
            }
        )
        .sheet(isPresented: $showNewEventView) {
            NewEventView(viewModel: viewModel)
        }
    }
}

// 新規追加: 月間カレンダーを表示し、選択した日のイベント一覧を表示するビュー
struct MonthTimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var selectedDate: Date
    @Binding var selectedEventID: UUID?
    
    var body: some View {
        VStack {
            // 1) 月間カレンダーを表示（例: SwiftUI のグラフィカルDatePicker）
            DatePicker(
                "月間カレンダー",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            .labelsHidden().environment(\.locale, Locale(identifier: "ja_JP"))
            .tint(.black)
            
            // 2) 選択した日付のイベント一覧を表示
            ScrollView {
                VStack(spacing: 0) {
                    // ZStackを使用して連続する垂直線を描画
                    ZStack(alignment: .leading) {
                        // 背景の連続垂直線
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 1)
                            .offset(x: 68)
                        VStack{
                            ForEach(eventsForSelectedDate, id: \.id) { event in
                                TimelineRow(event: event, selectedEventID: $selectedEventID)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var eventsForSelectedDate: [TimelineView.TimelineEvent] {
        viewModel.events.filter { event in
            guard let date = dateFromString(event.time) else { return false }
            return isSameDay(date, selectedDate)
        }
    }
    
    private func dateFromString(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.date(from: str)
    }
    
    private func isSameDay(_ d1: Date, _ d2: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.year, from: d1) == cal.component(.year, from: d2)
            && cal.component(.month, from: d1) == cal.component(.month, from: d2)
            && cal.component(.day, from: d1) == cal.component(.day, from: d2)
    }
}


// 新規追加: 1週間の日付を横並びで表示し、選択した日のイベント一覧を表示するビュー
struct WeekTimelineView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @Binding var selectedDate: Date
    @Binding var selectedEventID: UUID?
    
    // 曜日を取得するフォーマッタ（例: "土", "日", "月"...）
    private let dayOfWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "E"   // 曜日（例: 土, 日, 月 ...）
        return f
    }()
    
    // 日を取得するフォーマッタ（例: "25"）
    private let dayOfMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "d"   // 日（例: 25）
        return f
    }()
    
    // selectedDate の3日前～3日後の計7日間を表示
    private var weekDates: [Date] {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -3, to: selectedDate) else {
            return []
        }
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startDate)
        }
    }
    
    private let yearMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "yyyy年M月"
        return f
    }()
    
    private func eventCount(for date: Date) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return viewModel.events.filter { event in
            guard let eventDate = formatter.date(from: event.time) else { return false }
            return isSameDay(eventDate, date)
        }.count
    }
    
    var body: some View {
        VStack {
            // 1) 横スクロールで日付を並べる
            HStack{
                Spacer()
                Text(yearMonthFormatter.string(from: selectedDate))
                    .font(.system(size: 18))
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(weekDates, id: \.self) { date in
                        let weekday = dayOfWeekFormatter.string(from: date)    // 例: "土"
                        let day = dayOfMonthFormatter.string(from: date)         // 例: "25"
                        let count = eventCount(for: date)                        // その日のイベント数
                        VStack {
                            VStack(spacing: 5) {
                                // 上段: 曜日
                                Text(weekday)
                                    .font(.system(size: 14))
                                
                                // 中段: 日付（選択時は丸背景）
                                ZStack {
                                    Circle()
                                        .fill(isSameDay(date, selectedDate) ? Color.black : Color.clear)
                                        .frame(width: 36, height: 36)
                                    Text(day)
                                        .font(.system(size: 16))
                                        .foregroundColor(isSameDay(date, selectedDate) ? .white : .black)
                                }.frame(height: 40)
                                if count > 0 {
                                       // イベント数に応じて最大3つまでドットを表示
                                       HStack(spacing: 2) {
                                           ForEach(0..<min(count, 3), id: \.self) { _ in
                                               Circle()
                                                   .fill(Color.black)
                                                   .frame(width: 6, height: 6)
                                           }
                                       }
                                       .frame(height: 10)
                                   } else {
                                       // ドットがない場合でも同じ高さを確保しておけば
                                       // 日付の位置が変わらない
                                       Spacer()
                                           .frame(height: 10)
                                   }
                            }
                            .padding(.horizontal, 8)
                            .onTapGesture {
                                selectedDate = date
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // 2) 選択した日付のイベント一覧を表示
            ScrollView {
                VStack(spacing: 0) {
                    // ZStackを使用して連続する垂直線を描画
                    ZStack(alignment: .leading) {
                        // 背景の連続垂直線
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 1)
                            .offset(x: 68)
                        VStack{
                        ForEach(eventsForSelectedDate, id: \.id) { event in
                            TimelineRow(event: event, selectedEventID: $selectedEventID)
                        }
                    }
                    }
                }
            }
        }
    }
    
    // 選択した日付と同じ日のイベントのみを抽出
    private var eventsForSelectedDate: [TimelineView.TimelineEvent] {
        viewModel.events.filter { event in
            guard let date = dateFromString(event.time) else { return false }
            return isSameDay(date, selectedDate)
        }
    }
    
    // 日付文字列 -> Date に変換するヘルパー
    private func dateFromString(_ str: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.date(from: str)
    }
    
    // 同じ日かどうかを判定するヘルパー
    private func isSameDay(_ d1: Date, _ d2: Date) -> Bool {
        let cal = Calendar.current
        return cal.component(.year, from: d1) == cal.component(.year, from: d2)
            && cal.component(.month, from: d1) == cal.component(.month, from: d2)
            && cal.component(.day, from: d1) == cal.component(.day, from: d2)
    }
}



// タイムラインの各行を表示するサブビュー（ズームアニメーション付き）
// 変更後（画像表示を追加）
struct TimelineRow: View {
    let event: TimelineView.TimelineEvent
    @Binding var selectedEventID: UUID?
    var formattedTime: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy/MM/dd HH:mm" // 保存時のフォーマットに合わせる
        if let date = inputFormatter.date(from: event.time) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "HH:mm" // 時:分のみ表示
            return outputFormatter.string(from: date)
        } else {
            return event.time
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 0) {
                // 時刻表示
                Text(formattedTime)
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                    .frame(width: 55, alignment: .trailing)
                    .padding(.trailing, 8)
                
                // ステータスドット
                Circle()
                    .fill(event.color)
                    .frame(width: 12, height: 12)
                
                // タイトル表示
                VStack{
                    HStack(alignment: .center, spacing: 0) {
                        Text(event.title)
                            .font(.system(size: 18))
                            .padding(.leading, 8)
                        Spacer()
                        if selectedEventID != event.id,let imageURL = event.imageURL, let url = URL(string: imageURL) {
                            Image(systemName: "photo").padding(.trailing)
                        }
                    }
                    if selectedEventID == event.id, let imageURL = event.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .frame(width: 150, height: 150)
                                    .foregroundColor(.gray)
                                    .cornerRadius(10)
                                    .shimmer(true)
                            case .success(let image):
                                image.resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 150, maxHeight: 150)
                                    .cornerRadius(10)
                            case .failure:
                                Image(systemName: "photo")
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: selectedEventID)
                    }
                }
                .padding(.vertical, 12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(4)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .scaleEffect(selectedEventID == event.id ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: selectedEventID)
            }
            .onTapGesture {
                if selectedEventID == event.id {
                    selectedEventID = nil
                } else {
                    selectedEventID = event.id
                }
            }
        }
    }
}


struct NewEventView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: TimelineViewModel
    @State private var eventDate: Date = Date()
    @State private var title: String = ""
    @State private var isOshiActivity: Bool = true
    @State private var showDatePicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker: Bool = false

    
    var body: some View {
        VStack{
            VStack {
                Button(action: {
                    showImagePicker = true
                }) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(10)
                            .frame(width: 120, height: 120)
                    } else {
                        ZStack{
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.black)
                            RoundedRectangle(cornerRadius: 10, style: .continuous).foregroundColor(.black).opacity(0.3)
                                .frame(width: 120, height: 100)
                            Image(systemName: "camera.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                        }
                    }
                }
            }
            
            HStack{
                Text("タイトル")
                Spacer()
                TextField("タイトル", text: $title)
                    .multilineTextAlignment(.trailing)
            }
            HStack{
                Text("日付を指定")
                Spacer()
                DatePickerTextField(date: $eventDate, placeholder: "日付と時間を指定")
                    .frame(height: 44)
            }
            
            Toggle(isOn: $isOshiActivity) {
                Text(isOshiActivity ? "推しの活動" : "自分の活動")
            }.toggleStyle(SwitchToggleStyle(tint: Color.blue))
            
            Button("登録") {
                let color: Color = isOshiActivity ? .gray : .blue
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy/MM/dd HH:mm" // フォーマットはお好みで変更可能
                let timeString = dateFormatter.string(from: eventDate)
                let newEvent = TimelineView.TimelineEvent(time: timeString, title: title, color: color, image: selectedImage, imageURL: nil)
                viewModel.addEvent(event: newEvent)
                presentationMode.wrappedValue.dismiss()
            }
            .padding(.vertical)
        }
        .font(.system(size: 20))
        .padding(.horizontal)
        .sheet(isPresented: $showImagePicker) {
            ImageTimeLinePicker(selectedImage: $selectedImage)
        }
    }
}

// 追加: UIDatePicker を inputView として使うための UIViewRepresentable
struct DatePickerTextField: UIViewRepresentable {
    @Binding var date: Date
    var placeholder: String
    
    // 表示用フォーマッタ（お好みで調整可能）
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    
    func makeUIView(context: Context) -> UITextField {
        let textField = NoCaretTextField(frame: .zero)
        textField.placeholder = placeholder
        textField.inputView = context.coordinator.datePicker
        textField.inputAccessoryView = context.coordinator.toolbar
        textField.delegate = context.coordinator
        textField.textAlignment = .right
        textField.font = UIFont.systemFont(ofSize: 20)
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        // 日付が更新されたらテキストも更新
        uiView.text = dateFormatter.string(from: date)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, dateFormatter: dateFormatter)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: DatePickerTextField
        var dateFormatter: DateFormatter
        
        // 下部に表示する UIDatePicker
        let datePicker = UIDatePicker()
        
        // キーボード上部に表示するツールバー（完了ボタンなど）
        lazy var toolbar: UIToolbar = {
            let tb = UIToolbar()
            tb.sizeToFit()
            let doneButton = UIBarButtonItem(title: "完了", style: .done, target: self, action: #selector(doneTapped))
            tb.setItems([doneButton], animated: false)
            return tb
        }()
        
        init(_ parent: DatePickerTextField, dateFormatter: DateFormatter) {
            self.parent = parent
            self.dateFormatter = dateFormatter
            super.init()
            
            datePicker.preferredDatePickerStyle = .wheels
            datePicker.datePickerMode = .dateAndTime
            datePicker.locale = Locale(identifier: "ja_JP")
            datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        }
        
        // 日付が変わったらバインド先の変数を更新
        @objc func dateChanged() {
            parent.date = datePicker.date
        }
        
        // Doneボタンでキーボードを閉じる
        @objc func doneTapped() {
            parent.date = datePicker.date
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
    }
}

// 新規追加：ImagePicker.swift として追加可能なコード
struct ImageTimeLinePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedImage: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImageTimeLinePicker
        init(_ parent: ImageTimeLinePicker) {
            self.parent = parent
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}


class NoCaretTextField: UITextField {
    // キャレット（カーソル）を非表示にする
    override func caretRect(for position: UITextPosition) -> CGRect {
        return .zero
    }
}

// プレビュー
struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
                TimelineView()
//        NewEventView(viewModel: TimelineViewModel())
    }
}
