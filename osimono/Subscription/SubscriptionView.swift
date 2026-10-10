//
//  SubscriptionView.swift
//  osimono
//
//  Created by Apple on 2025/07/12.
//

import SwiftUI
import StoreKit
import FirebaseAuth
import FirebaseDatabase
import FirebaseAnalytics

struct SubscriptionPreView: View {
    let source: PaywallSource
    let storyCharacter: StoryCharacter?

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedProduct: Product?
    @State private var animateContent = false
    @State private var oshiName: String?
    @State private var oshiImageUrl: String?
    @State private var showOfferCodeRedemption = false
    @State private var offerCodeCopied = false
    @State private var appearedAt = Date()

    init(source: PaywallSource, storyCharacter: StoryCharacter? = nil) {
        self.source = source
        self.storyCharacter = storyCharacter
        _oshiName = State(initialValue: storyCharacter?.name)
        _oshiImageUrl = State(initialValue: storyCharacter?.imageURL)
    }

    static let pink = Color(red: 0.93, green: 0.40, blue: 0.62)
    static let lavender = Color(red: 0.66, green: 0.45, blue: 0.95)
    static let periwinkle = Color(red: 0.45, green: 0.56, blue: 0.97)

    let primaryGradient = LinearGradient(
        colors: [SubscriptionPreView.pink, SubscriptionPreView.lavender, SubscriptionPreView.periwinkle],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    let accentColor = SubscriptionPreView.lavender

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                backgroundView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // 推しのアイコン + 見出し
                        heroSection

                        // 24時間限定オファー
                        if isWinBack, let expiresAt = PaywallCampaignManager.shared.winBackWindow?.end {
                            winBackOfferSection(expiresAt: expiresAt)
                        }

                        // 無料 / プレミアムの比較
                        comparisonSection

                        PremiumAppLockBenefitCard()
                            .padding(.horizontal, 20)

                        // 料金プラン
                        pricingSection

                        // 無料トライアルの流れ
                        if let product = selectedProduct,
                           let trialDays = subscriptionManager.freeTrialDays(for: product) {
                            trialTimelineSection(product: product, trialDays: trialDays)
                        }

                        // フッター
                        footerSection
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
            // 購入ボタンは常に画面下に固定
            .safeAreaInset(edge: .bottom) {
                if let product = selectedProduct {
                    purchaseBar(product: product)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    dismissButton
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("復元") { restorePurchases() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .disabled(isLoading)
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("通知"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            appearedAt = Date()
            PaywallAnalytics.logView(source: source)
            animateOnAppear()
            loadSelectedOshi()
        }
        .onDisappear {
            guard !subscriptionManager.isSubscribed else { return }
            PaywallAnalytics.logDismiss(
                source: source,
                secondsOnScreen: Int(Date().timeIntervalSince(appearedAt)),
                selectedProductID: selectedProduct?.id
            )
            if source == .onboarding {
                PaywallCampaignManager.shared.onboardingPaywallDismissedWithoutPurchase()
            }
        }
        .offerCodeRedemption(isPresented: $showOfferCodeRedemption) { _ in
            Task { await subscriptionManager.updateSubscriptionStatus() }
        }
        .onChange(of: subscriptionManager.subscriptionProducts) { products in
            if selectedProduct == nil {
                selectedProduct = defaultProduct(in: products)
            }
        }
        .onChange(of: subscriptionManager.isSubscribed) { isSubscribed in
            if isSubscribed {
                PaywallCampaignManager.shared.cancelWinBack()
                alertMessage = "サブスクリプションが開始されました！"
                showAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    // MARK: - Background
    private var backgroundView: some View {
        ZStack(alignment: .top) {
            Color(.systemGroupedBackground)

            LinearGradient(
                colors: [
                    SubscriptionPreView.pink.opacity(0.22),
                    SubscriptionPreView.lavender.opacity(0.12),
                    Color(.systemGroupedBackground).opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 460)
        }
        .ignoresSafeArea()
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 18) {
            if oshiName != nil {
                oshiHero
            } else {
                bannerHero
            }
            titleBlock
        }
    }

    // 推しがいる場合: 吹き出し + アイコン
    private var oshiHero: some View {
        VStack(spacing: 10) {
            Text(oshiLine)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .shadow(color: accentColor.opacity(0.18), radius: 10, x: 0, y: 4)
                )
                .overlay(alignment: .bottom) {
                    BubbleTail()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 18, height: 9)
                        .offset(y: 8)
                }
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 8)
                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.35), value: animateContent)

            oshiAvatar
        }
        .padding(.top, 8)
    }

    // 推しがいない場合: バナー画像
    private var bannerHero: some View {
        Image("subscription_banner")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: 190)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: accentColor.opacity(0.2), radius: 14, x: 0, y: 6)
            .padding(.horizontal, 20)
            .opacity(animateContent ? 1 : 0)
            .scaleEffect(animateContent ? 1 : 0.96)
            .animation(.easeOut(duration: 0.5), value: animateContent)
    }

    private var oshiAvatar: some View {
        ZStack {
            Circle()
                .fill(primaryGradient)
                .frame(width: 124, height: 124)
                .blur(radius: 18)
                .opacity(0.55)

            Circle()
                .fill(primaryGradient)
                .frame(width: 118, height: 118)

            Group {
                if let urlString = oshiImageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            oshiAvatarPlaceholder
                        }
                    }
                } else {
                    oshiAvatarPlaceholder
                }
            }
            .frame(width: 108, height: 108)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))

            // 王冠バッジ
            Image(systemName: "crown.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(primaryGradient))
                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
                .offset(x: 42, y: 42)
        }
        .opacity(animateContent ? 1 : 0)
        .scaleEffect(animateContent ? 1 : 0.8)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animateContent)
    }

    private var oshiAvatarPlaceholder: some View {
        ZStack {
            Color(.systemGray5)
            Text(String(oshiName?.prefix(1) ?? ""))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(accentColor)
        }
    }

    // MARK: - Title
    private var titleBlock: some View {
        VStack(spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: isWinBack ? "clock.fill" : "crown.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(isWinBack ? "24時間限定オファー" : "PREMIUM")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(isWinBack ? 0 : 1.5)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(primaryGradient))

            Text(headline)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(subheadline)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 15)
        .animation(.easeOut(duration: 0.5).delay(0.15), value: animateContent)
    }

    private var isWinBack: Bool {
        source == .winBack
    }

    private var headline: String {
        if let title = PaywallConfig.shared.title { return title }
        return oshiName.map { "\($0)と、もっと話そう" } ?? "推しとの時間を、もっと特別に"
    }

    // 入口に合わせて一番響く特典を伝える
    private var subheadline: String {
        if let subtitle = PaywallConfig.shared.subtitle { return subtitle }
        switch source {
        case .storyLimit:
            return StoryText.text("story_limit_premium_body")
        case .chatLimit, .groupChatLimit:
            return "回数を気にせず、好きなだけ話せます"
        case .oshiLimit:
            return "推しを何人でも登録できます"
        case .roleplay:
            return "ロールプレイで、特別なシチュエーションを楽しもう"
        case .winBack:
            return "今だけの特別価格でプレミアムを始めよう"
        default:
            return "すべての機能が使い放題になります"
        }
    }

    private var oshiLine: String {
        switch source {
        case .storyLimit:
            return StoryText.text("story_limit_oshi_line")
        case .chatLimit, .groupChatLimit:
            return "もっとお話ししたいな…"
        case .roleplay:
            return "この続き、一緒にしよ？"
        case .winBack:
            return "また会えてうれしい！"
        default:
            return "これからも、たくさん話そうね"
        }
    }

    // MARK: - Win-back Offer Section
    private func winBackOfferSection(expiresAt: Date) -> some View {
        VStack(spacing: 12) {
            Text(PaywallCampaignManager.winBackOfferLabel)
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(primaryGradient)

            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let remaining = max(Int(expiresAt.timeIntervalSince(timeline.date)), 0)
                Label(
                    String(format: "残り %02d:%02d:%02d", remaining / 3600, remaining % 3600 / 60, remaining % 60),
                    systemImage: "clock.fill"
                )
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.red)
            }

            HStack(spacing: 8) {
                Text("オファーコード")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(PaywallCampaignManager.winBackOfferCode)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
            }

            Button(action: redeemWinBackOffer) {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                    Text("コードをコピーして特典を受け取る")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(primaryGradient))
            }

            if offerCodeCopied {
                Text("コードをコピーしました。表示された画面に貼り付けてください")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(primaryGradient, lineWidth: 1.5)
        )
        .padding(.horizontal, 20)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.25), value: animateContent)
    }

    // MARK: - Comparison Section (無料 vs プレミアム)
    private struct ComparisonRow: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let free: String?       // nil = 利用不可
        let premium: String?    // nil = チェックマーク
        var emphasized = false
    }

    private var comparisonRows: [ComparisonRow] {
        let dailyLimit = PaywallConfig.shared.freeDailyMessageLimit
        let oshiLimit = OshiLimitManager.shared.freeUserOshiLimit
        return [
            ComparisonRow(icon: "bubble.left.and.bubble.right.fill", title: "チャット",
                          free: "1日\(dailyLimit)通", premium: "無制限",
                          emphasized: source == .chatLimit || source == .groupChatLimit || source == .storyLimit),
            ComparisonRow(icon: "theatermasks.fill", title: "ロールプレイ",
                          free: "お試し1回", premium: "使い放題",
                          emphasized: source == .roleplay),
            ComparisonRow(icon: "person.2.fill", title: "推し登録",
                          free: "\(oshiLimit)人まで", premium: "無制限",
                          emphasized: source == .oshiLimit),
            ComparisonRow(icon: "brain.head.profile", title: "会話の記憶",
                          free: "標準", premium: "拡張"),
            ComparisonRow(icon: "bell.badge.fill", title: "朝・夜のメッセージ",
                          free: nil, premium: nil),
            ComparisonRow(icon: "gift.fill", title: "誕生日・記念日",
                          free: nil, premium: nil),
            ComparisonRow(icon: "lock.shield.fill", title: NSLocalizedString("app_lock_title", comment: ""),
                          free: nil, premium: nil),
            ComparisonRow(icon: "rectangle.badge.xmark", title: "広告",
                          free: "あり", premium: "なし")
        ]
    }

    private let freeColumnWidth: CGFloat = 70
    private let premiumColumnWidth: CGFloat = 84

    private var comparisonSection: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack(spacing: 0) {
                Text("プレミアム特典")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer(minLength: 8)
                Text("無料")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: freeColumnWidth)
                Text("PREMIUM")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(primaryGradient)
                    .frame(width: premiumColumnWidth)
            }
            .padding(.vertical, 14)

            ForEach(comparisonRows) { row in
                Divider().padding(.trailing, premiumColumnWidth)
                comparisonRowView(row)
            }
        }
        .padding(.leading, 16)
        .background(alignment: .trailing) {
            // プレミアム列のハイライト
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(primaryGradient.opacity(0.1))
                .frame(width: premiumColumnWidth)
                .padding(.vertical, 6)
        }
        .padding(.trailing, 6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(0.3), value: animateContent)
    }

    private func comparisonRowView(_ row: ComparisonRow) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: row.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryGradient)
                    .frame(width: 22)
                Text(row.title)
                    .font(.system(size: 14, weight: row.emphasized ? .bold : .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)

            Group {
                if let free = row.free {
                    Text(free)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .frame(width: freeColumnWidth)

            Group {
                if let premium = row.premium {
                    Text(premium)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryGradient)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(primaryGradient)
                }
            }
            .frame(width: premiumColumnWidth)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Pricing Section
    private var pricingSection: some View {
        VStack(spacing: 14) {
            if subscriptionManager.isLoading && subscriptionManager.subscriptionProducts.isEmpty {
                LoadingPreView()
            } else if let errorMessage = subscriptionManager.errorMessage {
                ErrorView(
                    errorMessage: errorMessage,
                    primaryGradient: primaryGradient,
                    onRetry: {
                        Task { await subscriptionManager.requestProducts() }
                    },
                    onDebug: { subscriptionManager.printDebugInfo() }
                )
                .padding(.horizontal, 20)
            } else if subscriptionManager.subscriptionProducts.isEmpty {
                EmptyStatePreView(
                    primaryGradient: primaryGradient,
                    onReload: {
                        Task { await subscriptionManager.requestProducts() }
                    },
                    onDebug: { subscriptionManager.printDebugInfo() }
                )
                .padding(.horizontal, 20)
            } else {
                let sortedProducts = subscriptionManager.subscriptionProducts.sorted { p1, p2 in
                    if p1.id.contains("yearlySub") { return true }
                    if p2.id.contains("yearlySub") { return false }
                    if p1.id.contains("monthlySub") { return true }
                    return false
                }

                let savingsPercent = yearlySavingsPercent(in: sortedProducts)

                Text("プランを選ぶ")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                ForEach(Array(sortedProducts.enumerated()), id: \.element.id) { index, product in
                    CompactPlanCard(
                        product: product,
                        subscriptionManager: subscriptionManager,
                        isSelected: selectedProduct?.id == product.id,
                        onSelect: { selectPlan(product) },
                        primaryGradient: primaryGradient,
                        savingsPercent: savingsPercent
                    )
                    .padding(.horizontal, 20)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.4 + Double(index) * 0.08), value: animateContent)
                }
            }
        }
    }

    // MARK: - Trial Timeline
    private func trialTimelineSection(product: Product, trialDays: Int) -> some View {
        let price = "\(product.displayPrice)/\(CompactPlanCard.periodText(for: product))"
        return VStack(alignment: .leading, spacing: 16) {
            Text("無料トライアルのしくみ")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 0) {
                timelineStep(
                    icon: "lock.open.fill",
                    title: "今日",
                    detail: "すべてのプレミアム機能が使えるようになります",
                    isLast: false
                )
                timelineStep(
                    icon: "heart.fill",
                    title: "無料期間中（\(trialDays)日間）",
                    detail: "いつでも解約OK。料金は一切かかりません",
                    isLast: false
                )
                timelineStep(
                    icon: "star.fill",
                    title: "\(trialDays)日後",
                    detail: "\(price)で自動更新がはじまります。終了の24時間前までに解約すれば請求されません",
                    isLast: true
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 20)
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.6), value: animateContent)
    }

    private func timelineStep(icon: String, title: String, detail: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(primaryGradient))
                if !isLast {
                    Rectangle()
                        .fill(primaryGradient.opacity(0.35))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 5)
            .padding(.bottom, isLast ? 0 : 14)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Purchase Bar (画面下に固定)
    private func purchaseBar(product: Product) -> some View {
        let trialDays = subscriptionManager.freeTrialDays(for: product)
        let price = "\(product.displayPrice)/\(CompactPlanCard.periodText(for: product))"
        let ctaText = PaywallConfig.shared.ctaText
            ?? trialDays.map { "\($0)日間無料で試す" }
            ?? "プレミアムを始める"
        let note = trialDays.map { "\($0)日間無料、その後\(price)・いつでも解約OK" }
            ?? "\(price)・自動更新・いつでも解約OK"

        return VStack(spacing: 8) {
            Button(action: { purchaseSubscription(product) }) {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                        Text(ctaText)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(primaryGradient)
                )
                .shadow(color: accentColor.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .disabled(isLoading)

            Text(note)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { Divider() }
        )
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                NavigationLink("利用規約", destination: TermsOfServiceView())
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                NavigationLink("プライバシーポリシー", destination: PrivacyView())
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                Button("購入を復元") { restorePurchases() }
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }

            Text("購読は自動更新されます。無料期間・購読期間の終了24時間前までに解約しない限り、同じ期間・料金で自動更新されます。解約はApp Storeの設定から可能です。")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    // MARK: - Dismiss Button
    private var dismissButton: some View {
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                )
        }
    }

    // MARK: - Helper Functions
    private func animateOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation { animateContent = true }
        }

        selectedProduct = defaultProduct(in: subscriptionManager.subscriptionProducts)
    }

    private func selectPlan(_ product: Product) {
        guard selectedProduct?.id != product.id else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedProduct = product
        }
        PaywallAnalytics.logPlanSelect(source: source, productID: product.id)
    }

    // 月額プランを初期選択にする（なければ年額→先頭）
    private func defaultProduct(in products: [SKProduct]) -> SKProduct? {
        products.first(where: { $0.id.contains("monthlySub") })
            ?? products.first(where: { $0.id.contains("yearlySub") })
            ?? products.first
    }

    // 年額プランの割引率（月額×12との比較。月額がなければ週額×52と比較）
    private func yearlySavingsPercent(in products: [SKProduct]) -> Int? {
        guard let yearly = products.first(where: { $0.id.contains("yearlySub") }) else { return nil }
        let baseline: Decimal
        if let monthly = products.first(where: { $0.id.contains("monthlySub") }) {
            baseline = monthly.price * 12
        } else if let weekly = products.first(where: { $0.id.contains("weeklySub") }) {
            baseline = weekly.price * 52
        } else {
            return nil
        }
        guard baseline > 0 else { return nil }
        let ratio = NSDecimalNumber(decimal: 1 - yearly.price / baseline).doubleValue
        let percent = Int((ratio * 100).rounded())
        return percent > 0 ? percent : nil
    }

    // ストーリーから渡された推しは、アプリ全体の選択中の推しで上書きしない。
    private func loadSelectedOshi() {
        guard storyCharacter == nil, source != .storyLimit else { return }
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let userRef = Database.database().reference().child("users").child(userId)
        userRef.child("selectedOshiId").observeSingleEvent(of: .value) { snapshot in
            guard let oshiId = snapshot.value as? String, !oshiId.isEmpty else { return }
            Database.database().reference().child("oshis").child(userId).child(oshiId)
                .observeSingleEvent(of: .value) { oshiSnapshot in
                    guard let value = oshiSnapshot.value as? [String: Any],
                          let name = value["name"] as? String, !name.isEmpty else { return }
                    DispatchQueue.main.async {
                        oshiName = name
                        oshiImageUrl = value["imageUrl"] as? String
                    }
                }
        }
    }

    private func purchaseSubscription(_ product: Product) {
        isLoading = true
        let hasTrial = subscriptionManager.freeTrialDays(for: product) != nil
        PaywallAnalytics.logPurchaseStart(source: source, productID: product.id, hasTrial: hasTrial)
        Task {
            do {
                let transaction = try await subscriptionManager.purchase(product)
                if transaction != nil {
                    PaywallAnalytics.logPurchaseSuccess(
                        source: source,
                        productID: product.id,
                        price: product.price,
                        currency: product.priceFormatStyle.currencyCode,
                        hasTrial: hasTrial
                    )
                    generateHapticFeedback()
                } else {
                    PaywallAnalytics.logPurchaseFail(source: source, productID: product.id, result: "cancelled")
                    alertMessage = "購入がキャンセルされました"
                    showAlert = true
                }
            } catch {
                PaywallAnalytics.logPurchaseFail(source: source, productID: product.id, result: "error")
                alertMessage = "購入に失敗しました: \(error.localizedDescription)"
                showAlert = true
            }
            isLoading = false
        }
    }

    private func redeemWinBackOffer() {
        UIPasteboard.general.string = PaywallCampaignManager.winBackOfferCode
        offerCodeCopied = true
        Analytics.logEvent("win_back_redeem_tap", parameters: ["offer_code": PaywallCampaignManager.winBackOfferCode])
        showOfferCodeRedemption = true
    }

    private func restorePurchases() {
        isLoading = true
        Task {
            await subscriptionManager.restorePurchases()
            alertMessage = subscriptionManager.isSubscribed ? "購入が復元されました" : "復元できる購入がありませんでした"
            showAlert = true
            isLoading = false
        }
    }

    private func generateHapticFeedback() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Bubble Tail (吹き出しのしっぽ)
struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Compact Plan Card
struct CompactPlanCard: View {
    let product: Product
    let subscriptionManager: SubscriptionManager
    let isSelected: Bool
    let onSelect: () -> Void
    let primaryGradient: LinearGradient
    var savingsPercent: Int? = nil

    var isYearly: Bool { product.id.contains("yearlySub") }
    var isMonthly: Bool { product.id.contains("monthlySub") }
    var isWeekly: Bool { product.id.contains("weeklySub") }

    var planName: String {
        if isYearly { return "年間プラン" }
        if isMonthly { return "月間プラン" }
        return "週間プラン"
    }

    static func periodText(for product: Product) -> String {
        if product.id.contains("yearlySub") { return "年" }
        if product.id.contains("monthlySub") { return "月" }
        return "週"
    }

    var monthlyEquivalentText: String {
        // 円は整数、ドルなどは小数2桁で表示
        let digits = product.priceFormatStyle.currencyCode == "JPY" ? 0 : 2
        return (product.price / 12).formatted(product.priceFormatStyle.precision(.fractionLength(digits)))
    }

    var trialDays: Int? { subscriptionManager.freeTrialDays(for: product) }

    var badgeText: String? {
        guard isYearly else { return nil }
        return savingsPercent.map { "一番人気・\($0)%お得" } ?? "一番人気"
    }

    private let cornerRadius: CGFloat = 18

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // 選択インジケーター
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.clear : Color(.tertiaryLabel), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(primaryGradient)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                // プラン情報
                VStack(alignment: .leading, spacing: 4) {
                    Text(planName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    if let trialDays = trialDays {
                        Label("\(trialDays)日間無料", systemImage: "gift.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(SubscriptionPreView.pink)
                    }
                }

                Spacer(minLength: 8)

                // 価格
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text(product.displayPrice)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                        Text("/\(Self.periodText(for: product))")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? primaryGradient : LinearGradient(colors: [.primary], startPoint: .leading, endPoint: .trailing))

                    if isYearly {
                        Text("月あたり \(monthlyEquivalentText)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, badgeText != nil ? 22 : 16)
            .padding(.bottom, 16)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isSelected
                          ? AnyShapeStyle(primaryGradient.opacity(0.08))
                          : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isSelected
                            ? AnyShapeStyle(primaryGradient)
                            : AnyShapeStyle(Color(.separator).opacity(0.6)),
                            lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? SubscriptionPreView.lavender.opacity(0.18) : .clear, radius: 10, x: 0, y: 4)
            .overlay(alignment: .topLeading) {
                if let badgeText = badgeText {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(badgeText)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(LinearGradient(colors: [.orange, SubscriptionPreView.pink], startPoint: .leading, endPoint: .trailing))
                    )
                    .offset(x: 16, y: -10)
                }
            }
            .padding(.top, badgeText != nil ? 10 : 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Loading View
struct LoadingPreView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.1)
                .tint(.purple)
            
            Text("プランを読み込み中...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let errorMessage: String
    let primaryGradient: LinearGradient
    let onRetry: () -> Void
    let onDebug: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            
            Text("読み込みに失敗しました")
                .font(.system(size: 14, weight: .semibold))
            
            Text(errorMessage)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button("再試行") { onRetry() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(primaryGradient)
                    .cornerRadius(16)
                
                Button("デバッグ") { onDebug() }
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
        )
    }
}

// MARK: - Empty State View
struct EmptyStatePreView: View {
    let primaryGradient: LinearGradient
    let onReload: () -> Void
    let onDebug: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 28))
                .foregroundColor(.gray)
            
            Text("利用可能なプランがありません")
                .font(.system(size: 14, weight: .semibold))
            
            HStack(spacing: 12) {
                Button("再読み込み") { onReload() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(primaryGradient)
                    .cornerRadius(16)
                
                Button("デバッグ") { onDebug() }
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
        )
    }
}

#Preview {
    SubscriptionPreView(source: .settings)
}
