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
    
    // どのイベントがズームされているかを管理
    @State private var selectedEventID: UUID? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("表示モード", selection: $selectedMode) {
                ForEach(TimelineMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            // タイムラインリスト（連結されたイベント）
            ScrollView {
                VStack(spacing: 0) {
                    // ZStackを使用して連続する垂直線を描画
                    ZStack(alignment: .leading) {
                        // 背景の連続垂直線
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 1)
                            .offset(x: 68)
                        
                        // イベントリスト
                        VStack(spacing: 0) {
                            ForEach(viewModel.events) { event in
                                TimelineRow(event: event, selectedEventID: $selectedEventID)
                            }
                        }
                    }
                }
                .padding(.vertical)
                Button("新規イベント追加") {
                    showNewEventView = true
                }
                .padding()
            }
        }
        .sheet(isPresented: $showNewEventView) {
            NewEventView(viewModel: viewModel)
        }
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
            HStack {
                Text("画像")
                Spacer()
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipped()
                } else {
                    Text("画像未選択")
                        .foregroundColor(.gray)
                }
                Button(action: {
                    showImagePicker = true
                }) {
                    Text("選択")
                }
            }
            HStack{
                Text("日付を指定")
                Spacer()
                DatePickerTextField(date: $eventDate, placeholder: "日付と時間を指定")
                    .frame(height: 44)
            }
            HStack{
                Text("タイトル")
                Spacer()
                TextField("タイトル", text: $title)
                    .multilineTextAlignment(.trailing)
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
