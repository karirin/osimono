//
//  OshiItemEditView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI

struct OshiItemEditView: View {
    let item: OshiItem
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        // 実際の実装はOshiItemFormViewを参考にして編集機能を追加
        NavigationView {
            Text("編集画面")
                .navigationBarItems(leading:
                    Button("閉じる") {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
        }
    }
}
